package main

import (
    "bytes"
    "encoding/json"
    "fmt"
    "log"
    "net/http"
    "os"
    "sync"
    "time"

    "github.com/gorilla/mux"
    "github.com/google/uuid"
)

type Order struct {
    ID        string    `json:"id"`
    UserID    string    `json:"user_id"`
    ProductID string    `json:"product_id"`
    Quantity  int       `json:"quantity"`
    Total     float64   `json:"total"`
    Status    string    `json:"status"`
    CreatedAt time.Time `json:"created_at"`
    CellID    string    `json:"cell_id"`
}

type OrderService struct {
    CellID            string
    Orders            map[string]*Order
    mutex             sync.RWMutex
    Port              string
    CellAGatewayURL   string
    PaymentServiceURL string
}

func NewOrderService() *OrderService {
    return &OrderService{
        CellID:            getEnv("CELL_ID", "cell-b"),
        Orders:            make(map[string]*Order),
        Port:              getEnv("PORT", "8021"),
        CellAGatewayURL:   getEnv("CELL_A_GATEWAY_URL", "http://cell-a-gateway:8010"),
        PaymentServiceURL: getEnv("PAYMENT_SERVICE_URL", "http://cell-b-payment-service:8022"),
    }
}

func getEnv(key, defaultValue string) string {
    if value := os.Getenv(key); value != "" {
        return value
    }
    return defaultValue
}

func (s *OrderService) createOrder(w http.ResponseWriter, r *http.Request) {
    var order Order
    if err := json.NewDecoder(r.Body).Decode(&order); err != nil {
        http.Error(w, "Invalid request body", http.StatusBadRequest)
        return
    }

    // Validate product exists and update stock
    if !s.validateAndUpdateStock(order.ProductID, order.Quantity) {
        http.Error(w, "Product not found or insufficient stock", http.StatusBadRequest)
        return
    }

    s.mutex.Lock()
    defer s.mutex.Unlock()

    order.ID = uuid.New().String()
    order.CellID = s.CellID
    order.CreatedAt = time.Now()
    order.Status = "pending"
    s.Orders[order.ID] = &order

    w.Header().Set("Content-Type", "application/json")
    w.WriteHeader(http.StatusCreated)
    json.NewEncoder(w).Encode(map[string]interface{}{
        "success": true,
        "data":    order,
        "cell_id": s.CellID,
    })
}

func (s *OrderService) validateAndUpdateStock(productID string, quantity int) bool {
    stockUpdate := map[string]int{"quantity": quantity}
    jsonData, _ := json.Marshal(stockUpdate)
    
    req, err := http.NewRequest("PUT", fmt.Sprintf("%s/products/%s/stock", s.CellAGatewayURL, productID), bytes.NewBuffer(jsonData))
    if err != nil {
        log.Printf("Error creating request: %v", err)
        return false
    }
    req.Header.Set("Content-Type", "application/json")
    
    client := &http.Client{}
    resp, err := client.Do(req)
    if err != nil {
        log.Printf("Error updating stock: %v", err)
        return false
    }
    
    if err != nil || resp.StatusCode != http.StatusOK {
        return false
    }
    
    return true
}

func (s *OrderService) getOrder(w http.ResponseWriter, r *http.Request) {
    vars := mux.Vars(r)
    orderID := vars["id"]

    s.mutex.RLock()
    order, exists := s.Orders[orderID]
    s.mutex.RUnlock()

    w.Header().Set("Content-Type", "application/json")
    if !exists {
        w.WriteHeader(http.StatusNotFound)
        json.NewEncoder(w).Encode(map[string]interface{}{
            "success": false,
            "error":   "Order not found",
            "cell_id": s.CellID,
        })
        return
    }

    json.NewEncoder(w).Encode(map[string]interface{}{
        "success": true,
        "data":    order,
        "cell_id": s.CellID,
    })
}

func (s *OrderService) getAllOrders(w http.ResponseWriter, r *http.Request) {
    s.mutex.RLock()
    orders := make([]*Order, 0, len(s.Orders))
    for _, order := range s.Orders {
        orders = append(orders, order)
    }
    s.mutex.RUnlock()

    w.Header().Set("Content-Type", "application/json")
    json.NewEncoder(w).Encode(map[string]interface{}{
        "success": true,
        "data":    orders,
        "cell_id": s.CellID,
        "count":   len(orders),
    })
}

func (s *OrderService) updateOrderStatus(w http.ResponseWriter, r *http.Request) {
    vars := mux.Vars(r)
    orderID := vars["id"]
    
    var request struct {
        Status string `json:"status"`
    }
    
    if err := json.NewDecoder(r.Body).Decode(&request); err != nil {
        http.Error(w, "Invalid request body", http.StatusBadRequest)
        return
    }

    s.mutex.Lock()
    defer s.mutex.Unlock()

    order, exists := s.Orders[orderID]
    if !exists {
        w.WriteHeader(http.StatusNotFound)
        json.NewEncoder(w).Encode(map[string]interface{}{
            "success": false,
            "error":   "Order not found",
            "cell_id": s.CellID,
        })
        return
    }

    order.Status = request.Status

    w.Header().Set("Content-Type", "application/json")
    json.NewEncoder(w).Encode(map[string]interface{}{
        "success": true,
        "data":    order,
        "cell_id": s.CellID,
    })
}

func (s *OrderService) deleteOrder(w http.ResponseWriter, r *http.Request) {
    vars := mux.Vars(r)
    orderID := vars["id"]

    s.mutex.Lock()
    defer s.mutex.Unlock()

    if _, exists := s.Orders[orderID]; !exists {
        w.WriteHeader(http.StatusNotFound)
        json.NewEncoder(w).Encode(map[string]interface{}{
            "success": false,
            "error":   "Order not found",
            "cell_id": s.CellID,
        })
        return
    }

    delete(s.Orders, orderID)

    w.Header().Set("Content-Type", "application/json")
    json.NewEncoder(w).Encode(map[string]interface{}{
        "success": true,
        "message": "Order deleted successfully",
        "cell_id": s.CellID,
    })
}

func (s *OrderService) healthCheck(w http.ResponseWriter, r *http.Request) {
    w.Header().Set("Content-Type", "application/json")
    json.NewEncoder(w).Encode(map[string]interface{}{
        "status":      "healthy",
        "service":     "order-service",
        "cell_id":     s.CellID,
        "order_count": len(s.Orders),
        "timestamp":   time.Now(),
        "version":     "1.0.0",
    })
}

func main() {
    service := NewOrderService()
    
    r := mux.NewRouter()
    
    r.HandleFunc("/health", service.healthCheck).Methods("GET")
    r.HandleFunc("/readiness", service.healthCheck).Methods("GET")
    r.HandleFunc("/orders", service.createOrder).Methods("POST")
    r.HandleFunc("/orders", service.getAllOrders).Methods("GET")
    r.HandleFunc("/orders/{id}", service.getOrder).Methods("GET")
    r.HandleFunc("/orders/{id}/status", service.updateOrderStatus).Methods("PUT")
    r.HandleFunc("/orders/{id}", service.deleteOrder).Methods("DELETE")
    
    log.Printf("Cell B Order Service starting on port %s", service.Port)
    log.Printf("Cell A Gateway URL: %s", service.CellAGatewayURL)
    log.Printf("Payment Service URL: %s", service.PaymentServiceURL)
    
    log.Fatal(http.ListenAndServe(":"+service.Port, r))
}
