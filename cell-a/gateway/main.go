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
    UserServiceURL    string
    ProductServiceURL string
    CellBGatewayURL   string
    Port              string
}

func NewGateway() *Gateway {
    return &Gateway{
        CellID:            getEnv("CELL_ID", "cell-a"),
        UserServiceURL:    getEnv("USER_SERVICE_URL", "http://cell-a-user-service:8011"),
        ProductServiceURL: getEnv("PRODUCT_SERVICE_URL", "http://cell-a-product-service:8012"),
        CellBGatewayURL:   getEnv("CELL_B_GATEWAY_URL", "http://cell-b-gateway:8020"),
        Port:              getEnv("PORT", "8010"),
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

func (g *Gateway) handleUsers(w http.ResponseWriter, r *http.Request) {
    g.proxyRequest(g.UserServiceURL, w, r)
}

func (g *Gateway) handleProducts(w http.ResponseWriter, r *http.Request) {
    g.proxyRequest(g.ProductServiceURL, w, r)
}

func (g *Gateway) handleOrders(w http.ResponseWriter, r *http.Request) {
    g.proxyRequest(g.CellBGatewayURL, w, r)
}

func (g *Gateway) handleHealth(w http.ResponseWriter, r *http.Request) {
    w.Header().Set("Content-Type", "application/json")
    json.NewEncoder(w).Encode(map[string]interface{}{
        "status":     "healthy",
        "cell_id":    g.CellID,
        "services":   []string{"user-service", "product-service"},
        "timestamp":  time.Now(),
        "version":    "1.0.0",
        "endpoints": map[string]string{
            "user_service":    g.UserServiceURL,
            "product_service": g.ProductServiceURL,
            "cell_b_gateway":  g.CellBGatewayURL,
        },
    })
}

func main() {
    gateway := NewGateway()
    
    r := mux.NewRouter()
    
    r.HandleFunc("/health", gateway.handleHealth).Methods("GET")
    r.HandleFunc("/readiness", gateway.handleHealth).Methods("GET")
    r.PathPrefix("/users").HandlerFunc(gateway.handleUsers)
    r.PathPrefix("/products").HandlerFunc(gateway.handleProducts)
    r.PathPrefix("/orders").HandlerFunc(gateway.handleOrders)
    r.PathPrefix("/payments").HandlerFunc(gateway.handleOrders)
    
    log.Printf("Cell A Gateway starting on port %s", gateway.Port)
    log.Printf("User Service URL: %s", gateway.UserServiceURL)
    log.Printf("Product Service URL: %s", gateway.ProductServiceURL)
    log.Printf("Cell B Gateway URL: %s", gateway.CellBGatewayURL)
    
    log.Fatal(http.ListenAndServe(":"+gateway.Port, r))
}