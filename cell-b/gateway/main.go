package main

import (
    "bytes"
    "encoding/json"
    "io"
    "log"
    "net/http"
    "os"
    "time"

    "github.com/gorilla/mux"
)

type Gateway struct {
    CellID            string
    OrderServiceURL   string
    PaymentServiceURL string
    CellAGatewayURL   string
    Port              string
}

func NewGateway() *Gateway {
    return &Gateway{
        CellID:            getEnv("CELL_ID", "cell-b"),
        OrderServiceURL:   getEnv("ORDER_SERVICE_URL", "http://cell-b-order-service:8021"),
        PaymentServiceURL: getEnv("PAYMENT_SERVICE_URL", "http://cell-b-payment-service:8022"),
        CellAGatewayURL:   getEnv("CELL_A_GATEWAY_URL", "http://cell-a-gateway:8010"),
        Port:              getEnv("PORT", "8020"),
    }
}

func getEnv(key, defaultValue string) string {
    if value := os.Getenv(key); value != "" {
        return value
    }
    return defaultValue
}

func (g *Gateway) proxyRequest(targetURL string, w http.ResponseWriter, r *http.Request) {
    body, err := io.ReadAll(r.Body)
    if err != nil {
        http.Error(w, "Failed to read request body", http.StatusBadRequest)
        return
    }
    defer r.Body.Close()

    req, err := http.NewRequest(r.Method, targetURL+r.URL.Path, bytes.NewBuffer(body))
    if err != nil {
        http.Error(w, "Failed to create request", http.StatusInternalServerError)
        return
    }

    for key, values := range r.Header {
        for _, value := range values {
            req.Header.Add(key, value)
        }
    }

    req.Header.Set("X-Gateway-ID", g.CellID)
    req.Header.Set("X-Request-Time", time.Now().Format(time.RFC3339))
    req.Header.Set("X-Source-Cell", g.CellID)

    client := &http.Client{Timeout: 30 * time.Second}
    resp, err := client.Do(req)
    if err != nil {
        log.Printf("Error proxying request to %s: %v", targetURL, err)
        http.Error(w, "Service unavailable", http.StatusServiceUnavailable)
        return
    }
    defer resp.Body.Close()

    for key, values := range resp.Header {
        for _, value := range values {
            w.Header().Add(key, value)
        }
    }

    w.WriteHeader(resp.StatusCode)
    io.Copy(w, resp.Body)
}

func (g *Gateway) handleOrders(w http.ResponseWriter, r *http.Request) {
    g.proxyRequest(g.OrderServiceURL, w, r)
}

func (g *Gateway) handlePayments(w http.ResponseWriter, r *http.Request) {
    g.proxyRequest(g.PaymentServiceURL, w, r)
}

func (g *Gateway) handleUsers(w http.ResponseWriter, r *http.Request) {
    g.proxyRequest(g.CellAGatewayURL, w, r)
}

func (g *Gateway) handleProducts(w http.ResponseWriter, r *http.Request) {
    g.proxyRequest(g.CellAGatewayURL, w, r)
}

func (g *Gateway) handleHealth(w http.ResponseWriter, r *http.Request) {
    w.Header().Set("Content-Type", "application/json")
    json.NewEncoder(w).Encode(map[string]interface{}{
        "status":     "healthy",
        "cell_id":    g.CellID,
        "services":   []string{"order-service", "payment-service"},
        "timestamp":  time.Now(),
        "version":    "1.0.0",
        "endpoints": map[string]string{
            "order_service":   g.OrderServiceURL,
            "payment_service": g.PaymentServiceURL,
            "cell_a_gateway":  g.CellAGatewayURL,
        },
    })
}

func main() {
    gateway := NewGateway()
    
    r := mux.NewRouter()
    
    r.HandleFunc("/health", gateway.handleHealth).Methods("GET")
    r.HandleFunc("/readiness", gateway.handleHealth).Methods("GET")
    r.PathPrefix("/orders").HandlerFunc(gateway.handleOrders)
    r.PathPrefix("/payments").HandlerFunc(gateway.handlePayments)
    r.PathPrefix("/users").HandlerFunc(gateway.handleUsers)
    r.PathPrefix("/products").HandlerFunc(gateway.handleProducts)
    
    log.Printf("Cell B Gateway starting on port %s", gateway.Port)
    log.Printf("Order Service URL: %s", gateway.OrderServiceURL)
    log.Printf("Payment Service URL: %s", gateway.PaymentServiceURL)
    log.Printf("Cell A Gateway URL: %s", gateway.CellAGatewayURL)
    
    log.Fatal(http.ListenAndServe(":"+gateway.Port, r))
}
