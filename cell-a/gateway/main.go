package main

import (
    "bytes"
    "encoding/json"
    "io"
    "log"
    "net/http"
    "os"
    "time"
    "context"
    "sync"

    "github.com/gorilla/mux"
)

type Gateway struct {
    CellID            string
    UserServiceURL    string
    ProductServiceURL string
    CellBGatewayURL   string
    Port              string
    healthyServices   map[string]bool
    healthMutex       sync.RWMutex
}

func NewGateway() *Gateway {
    return &Gateway{
        CellID:            getEnv("CELL_ID", "cell-a"),
        UserServiceURL:    getEnv("USER_SERVICE_URL", "http://cell-a-user-service.cell-a:8011"),
        ProductServiceURL: getEnv("PRODUCT_SERVICE_URL", "http://cell-a-product-service.cell-a:8012"),
        CellBGatewayURL:   getEnv("CELL_B_GATEWAY_URL", "http://cell-b-gateway.cell-b:8020"),
        Port:              getEnv("PORT", "8010"),
        healthyServices:   make(map[string]bool),
    }
}

func getEnv(key, defaultValue string) string {
    if value := os.Getenv(key); value != "" {
        return value
    }
    return defaultValue
}

// ensureServiceHealthy pre-warms a service by making a health check request
func (g *Gateway) ensureServiceHealthy(serviceURL string, serviceName string) {
    g.healthMutex.RLock()
    if g.healthyServices[serviceName] {
        g.healthMutex.RUnlock()
        return
    }
    g.healthMutex.RUnlock()

    log.Printf("Pre-warming service: %s", serviceName)
    
    // Make a health check request to trigger scaling
    client := &http.Client{Timeout: 30 * time.Second}
    ctx, cancel := context.WithTimeout(context.Background(), 25*time.Second)
    defer cancel()
    
    req, err := http.NewRequestWithContext(ctx, "GET", serviceURL+"/health", nil)
    if err != nil {
        log.Printf("Failed to create health check request for %s: %v", serviceName, err)
        return
    }
    
    resp, err := client.Do(req)
    if err != nil {
        log.Printf("Health check failed for %s: %v", serviceName, err)
        return
    }
    defer resp.Body.Close()
    
    if resp.StatusCode == 200 {
        g.healthMutex.Lock()
        g.healthyServices[serviceName] = true
        g.healthMutex.Unlock()
        log.Printf("Service %s is now healthy", serviceName)
    }
}

// preWarmDependencies concurrently warms up all dependent services
func (g *Gateway) preWarmDependencies() {
    dependencies := map[string]string{
        "user-service":    g.UserServiceURL,
        "product-service": g.ProductServiceURL,
    }
    
    var wg sync.WaitGroup
    for serviceName, serviceURL := range dependencies {
        wg.Add(1)
        go func(name, url string) {
            defer wg.Done()
            g.ensureServiceHealthy(url, name)
        }(serviceName, serviceURL)
    }
    
    // Wait for all services to be warmed up (with timeout)
    done := make(chan struct{})
    go func() {
        wg.Wait()
        close(done)
    }()
    
    select {
    case <-done:
        log.Printf("All dependent services pre-warmed successfully")
    case <-time.After(30 * time.Second):
        log.Printf("Pre-warming timeout reached, proceeding anyway")
    }
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
    // Ensure user service is healthy before proxying
    g.ensureServiceHealthy(g.UserServiceURL, "user-service")
    g.proxyRequest(g.UserServiceURL, w, r)
}

func (g *Gateway) handleProducts(w http.ResponseWriter, r *http.Request) {
    // Ensure product service is healthy before proxying
    g.ensureServiceHealthy(g.ProductServiceURL, "product-service")
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
    
    // Pre-warm dependent services on startup
    go gateway.preWarmDependencies()
    
    log.Fatal(http.ListenAndServe(":"+gateway.Port, r))
}