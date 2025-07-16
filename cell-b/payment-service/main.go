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

type Payment struct {
    ID        string    `json:"id"`
    OrderID   string    `json:"order_id"`
    Amount    float64   `json:"amount"`
    Status    string    `json:"status"`
    Method    string    `json:"method"`
    CellID    string    `json:"cell_id"`
    CreatedAt time.Time `json:"created_at"`
}

type PaymentService struct {
    CellID          string
    Payments        map[string]*Payment
    mutex           sync.RWMutex
    Port            string
    OrderServiceURL string
}

func NewPaymentService() *PaymentService {
    return &PaymentService{
        CellID:          getEnv("CELL_ID", "cell-b"),
        Payments:        make(map[string]*Payment),
        Port:            getEnv("PORT", "8022"),
        OrderServiceURL: getEnv("ORDER_SERVICE_URL", "http://cell-b-order-service:8021"),
    }
}

func getEnv(key, defaultValue string) string {
    if value := os.Getenv(key); value != "" {
        return value
    }
    return defaultValue
}

func (s *PaymentService) createPayment(w http.ResponseWriter, r *http.Request) {
    var payment Payment
    if err := json.NewDecoder(r.Body).Decode(&payment); err != nil {
        http.Error(w, "Invalid request body", http.StatusBadRequest)
        return
    }

    // Validate order exists
    if !s.validateOrder(payment.OrderID) {
        http.Error(w, "Order not found", http.StatusBadRequest)
        return
    }

    s.mutex.Lock()
    defer s.mutex.Unlock()

    payment.ID = uuid.New().String()
    payment.CellID = s.CellID
    payment.CreatedAt = time.Now()
    payment.Status = "processing"
    s.Payments[payment.ID] = &payment

    // Simulate payment processing
    go s.processPayment(payment.ID)

    w.Header().Set("Content-Type", "application/json")
    w.WriteHeader(http.StatusCreated)
    json.NewEncoder(w).Encode(map[string]interface{}{
        "success": true,
        "data":    payment,
        "cell_id": s.CellID,
    })
}

func (s *PaymentService) validateOrder(orderID string) bool {
    resp, err := http.Get(fmt.Sprintf("%s/orders/%s", s.OrderServiceURL, orderID))
    if err != nil || resp.StatusCode != http.StatusOK {
        return false
    }
    return true
}

func (s *PaymentService) processPayment(paymentID string) {
    time.Sleep(2 * time.Second)
    
    s.mutex.Lock()
    defer s.mutex.Unlock()
    
    if payment, exists := s.Payments[paymentID]; exists {
        payment.Status = "completed"
        s.updateOrderStatus(payment.OrderID, "paid")
    }
}

func (s *PaymentService) updateOrderStatus(orderID, status string) {
    statusUpdate := map[string]string{"status": status}
    jsonData, _ := json.Marshal(statusUpdate)
    
    req, err := http.NewRequest("PUT", fmt.Sprintf("%s/orders/%s/status", s.OrderServiceURL, orderID), bytes.NewBuffer(jsonData))
    if err != nil {
        log.Printf("Error creating request: %v", err)
        return
    }
    req.Header.Set("Content-Type", "application/json")
    
    client := &http.Client{}
    resp, err := client.Do(req)
    if err != nil {
        log.Printf("Error updating order status: %v", err)
        return
    }
    defer resp.Body.Close()
}

func (s *PaymentService) getPayment(w http.ResponseWriter, r *http.Request) {
    vars := mux.Vars(r)
    paymentID := vars["id"]

    s.mutex.RLock()
    payment, exists := s.Payments[paymentID]
    s.mutex.RUnlock()

    w.Header().Set("Content-Type", "application/json")
    if !exists {
        w.WriteHeader(http.StatusNotFound)
        json.NewEncoder(w).Encode(map[string]interface{}{
            "success": false,
            "error":   "Payment not found",
            "cell_id": s.CellID,
        })
        return
    }

    json.NewEncoder(w).Encode(map[string]interface{}{
        "success": true,
        "data":    payment,
        "cell_id": s.CellID,
    })
}

func (s *PaymentService) getAllPayments(w http.ResponseWriter, r *http.Request) {
    s.mutex.RLock()
    payments := make([]*Payment, 0, len(s.Payments))
    for _, payment := range s.Payments {
        payments = append(payments, payment)
    }
    s.mutex.RUnlock()

    w.Header().Set("Content-Type", "application/json")
    json.NewEncoder(w).Encode(map[string]interface{}{
        "success": true,
        "data":    payments,
        "cell_id": s.CellID,
        "count":   len(payments),
    })
}

func (s *PaymentService) getPaymentsByOrder(w http.ResponseWriter, r *http.Request) {
    vars := mux.Vars(r)
    orderID := vars["order_id"]

    s.mutex.RLock()
    var orderPayments []*Payment
    for _, payment := range s.Payments {
        if payment.OrderID == orderID {
            orderPayments = append(orderPayments, payment)
        }
    }
    s.mutex.RUnlock()

    w.Header().Set("Content-Type", "application/json")
    json.NewEncoder(w).Encode(map[string]interface{}{
        "success":  true,
        "data":     orderPayments,
        "cell_id":  s.CellID,
        "count":    len(orderPayments),
        "order_id": orderID,
    })
}

func (s *PaymentService) refundPayment(w http.ResponseWriter, r *http.Request) {
    vars := mux.Vars(r)
    paymentID := vars["id"]

    s.mutex.Lock()
    defer s.mutex.Unlock()

    payment, exists := s.Payments[paymentID]
    if !exists {
        w.WriteHeader(http.StatusNotFound)
        json.NewEncoder(w).Encode(map[string]interface{}{
            "success": false,
            "error":   "Payment not found",
            "cell_id": s.CellID,
        })
        return
    }

    if payment.Status != "completed" {
        w.WriteHeader(http.StatusBadRequest)
        json.NewEncoder(w).Encode(map[string]interface{}{
            "success": false,
            "error":   "Payment cannot be refunded",
            "cell_id": s.CellID,
        })
        return
    }

    payment.Status = "refunded"

    w.Header().Set("Content-Type", "application/json")
    json.NewEncoder(w).Encode(map[string]interface{}{
        "success": true,
        "data":    payment,
        "cell_id": s.CellID,
    })
}

func (s *PaymentService) healthCheck(w http.ResponseWriter, r *http.Request) {
    w.Header().Set("Content-Type", "application/json")
    json.NewEncoder(w).Encode(map[string]interface{}{
        "status":        "healthy",
        "service":       "payment-service",
        "cell_id":       s.CellID,
        "payment_count": len(s.Payments),
        "timestamp":     time.Now(),
        "version":       "1.0.0",
    })
}

func main() {
    service := NewPaymentService()
    
    r := mux.NewRouter()
    
    r.HandleFunc("/health", service.healthCheck).Methods("GET")
    r.HandleFunc("/readiness", service.healthCheck).Methods("GET")
    r.HandleFunc("/payments", service.createPayment).Methods("POST")
    r.HandleFunc("/payments", service.getAllPayments).Methods("GET")
    r.HandleFunc("/payments/{id}", service.getPayment).Methods("GET")
    r.HandleFunc("/payments/{id}/refund", service.refundPayment).Methods("POST")
    r.HandleFunc("/payments/order/{order_id}", service.getPaymentsByOrder).Methods("GET")
    
    log.Printf("Cell B Payment Service starting on port %s", service.Port)
    log.Printf("Order Service URL: %s", service.OrderServiceURL)
    
    log.Fatal(http.ListenAndServe(":"+service.Port, r))
}
