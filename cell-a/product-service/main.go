package main

import (
    "encoding/json"
    "log"
    "net/http"
    "os"
    "sync"
    "time"

    "github.com/gorilla/mux"
    "github.com/google/uuid"
)

type Product struct {
    ID          string    `json:"id"`
    Name        string    `json:"name"`
    Description string    `json:"description"`
    Price       float64   `json:"price"`
    Stock       int       `json:"stock"`
    CellID      string    `json:"cell_id"`
    CreatedAt   time.Time `json:"created_at"`
}

type ProductService struct {
    CellID   string
    Products map[string]*Product
    mutex    sync.RWMutex
    Port     string
}

func NewProductService() *ProductService {
    return &ProductService{
        CellID:   getEnv("CELL_ID", "cell-a"),
        Products: make(map[string]*Product),
        Port:     getEnv("PORT", "8012"),
    }
}

func getEnv(key, defaultValue string) string {
    if value := os.Getenv(key); value != "" {
        return value
    }
    return defaultValue
}

func (s *ProductService) createProduct(w http.ResponseWriter, r *http.Request) {
    var product Product
    if err := json.NewDecoder(r.Body).Decode(&product); err != nil {
        http.Error(w, "Invalid request body", http.StatusBadRequest)
        return
    }

    s.mutex.Lock()
    defer s.mutex.Unlock()

    product.ID = uuid.New().String()
    product.CellID = s.CellID
    product.CreatedAt = time.Now()
    s.Products[product.ID] = &product

    w.Header().Set("Content-Type", "application/json")
    w.WriteHeader(http.StatusCreated)
    json.NewEncoder(w).Encode(map[string]interface{}{
        "success": true,
        "data":    product,
        "cell_id": s.CellID,
    })
}

func (s *ProductService) getProduct(w http.ResponseWriter, r *http.Request) {
    vars := mux.Vars(r)
    productID := vars["id"]

    s.mutex.RLock()
    product, exists := s.Products[productID]
    s.mutex.RUnlock()

    w.Header().Set("Content-Type", "application/json")
    if !exists {
        w.WriteHeader(http.StatusNotFound)
        json.NewEncoder(w).Encode(map[string]interface{}{
            "success": false,
            "error":   "Product not found",
            "cell_id": s.CellID,
        })
        return
    }

    json.NewEncoder(w).Encode(map[string]interface{}{
        "success": true,
        "data":    product,
        "cell_id": s.CellID,
    })
}

func (s *ProductService) getAllProducts(w http.ResponseWriter, r *http.Request) {
    s.mutex.RLock()
    products := make([]*Product, 0, len(s.Products))
    for _, product := range s.Products {
        products = append(products, product)
    }
    s.mutex.RUnlock()

    w.Header().Set("Content-Type", "application/json")
    json.NewEncoder(w).Encode(map[string]interface{}{
        "success": true,
        "data":    products,
        "cell_id": s.CellID,
        "count":   len(products),
    })
}

func (s *ProductService) updateStock(w http.ResponseWriter, r *http.Request) {
    vars := mux.Vars(r)
    productID := vars["id"]
    
    var request struct {
        Quantity int `json:"quantity"`
    }
    
    if err := json.NewDecoder(r.Body).Decode(&request); err != nil {
        http.Error(w, "Invalid request body", http.StatusBadRequest)
        return
    }

    s.mutex.Lock()
    defer s.mutex.Unlock()

    product, exists := s.Products[productID]
    if !exists {
        w.WriteHeader(http.StatusNotFound)
        json.NewEncoder(w).Encode(map[string]interface{}{
            "success": false,
            "error":   "Product not found",
            "cell_id": s.CellID,
        })
        return
    }

    if product.Stock < request.Quantity {
        w.WriteHeader(http.StatusBadRequest)
        json.NewEncoder(w).Encode(map[string]interface{}{
            "success": false,
            "error":   "Insufficient stock",
            "cell_id": s.CellID,
        })
        return
    }

    product.Stock -= request.Quantity

    w.Header().Set("Content-Type", "application/json")
    json.NewEncoder(w).Encode(map[string]interface{}{
        "success": true,
        "data":    product,
        "cell_id": s.CellID,
    })
}

func (s *ProductService) updateProduct(w http.ResponseWriter, r *http.Request) {
    vars := mux.Vars(r)
    productID := vars["id"]

    var updates Product
    if err := json.NewDecoder(r.Body).Decode(&updates); err != nil {
        http.Error(w, "Invalid request body", http.StatusBadRequest)
        return
    }

    s.mutex.Lock()
    defer s.mutex.Unlock()

    product, exists := s.Products[productID]
    if !exists {
        w.WriteHeader(http.StatusNotFound)
        json.NewEncoder(w).Encode(map[string]interface{}{
            "success": false,
            "error":   "Product not found",
            "cell_id": s.CellID,
        })
        return
    }

    if updates.Name != "" {
        product.Name = updates.Name
    }
    if updates.Description != "" {
        product.Description = updates.Description
    }
    if updates.Price > 0 {
        product.Price = updates.Price
    }
    if updates.Stock >= 0 {
        product.Stock = updates.Stock
    }

    w.Header().Set("Content-Type", "application/json")
    json.NewEncoder(w).Encode(map[string]interface{}{
        "success": true,
        "data":    product,
        "cell_id": s.CellID,
    })
}

func (s *ProductService) deleteProduct(w http.ResponseWriter, r *http.Request) {
    vars := mux.Vars(r)
    productID := vars["id"]

    s.mutex.Lock()
    defer s.mutex.Unlock()

    if _, exists := s.Products[productID]; !exists {
        w.WriteHeader(http.StatusNotFound)
        json.NewEncoder(w).Encode(map[string]interface{}{
            "success": false,
            "error":   "Product not found",
            "cell_id": s.CellID,
        })
        return
    }

    delete(s.Products, productID)

    w.Header().Set("Content-Type", "application/json")
    json.NewEncoder(w).Encode(map[string]interface{}{
        "success": true,
        "message": "Product deleted successfully",
        "cell_id": s.CellID,
    })
}

func (s *ProductService) healthCheck(w http.ResponseWriter, r *http.Request) {
    w.Header().Set("Content-Type", "application/json")
    json.NewEncoder(w).Encode(map[string]interface{}{
        "status":        "healthy",
        "service":       "product-service",
        "cell_id":       s.CellID,
        "product_count": len(s.Products),
        "timestamp":     time.Now(),
        "version":       "1.0.0",
    })
}

func main() {
    service := NewProductService()
    
    r := mux.NewRouter()
    
    r.HandleFunc("/health", service.healthCheck).Methods("GET")
    r.HandleFunc("/readiness", service.healthCheck).Methods("GET")
    r.HandleFunc("/products", service.createProduct).Methods("POST")
    r.HandleFunc("/products", service.getAllProducts).Methods("GET")
    r.HandleFunc("/products/{id}", service.getProduct).Methods("GET")
    r.HandleFunc("/products/{id}", service.updateProduct).Methods("PUT")
    r.HandleFunc("/products/{id}", service.deleteProduct).Methods("DELETE")
    r.HandleFunc("/products/{id}/stock", service.updateStock).Methods("PUT")
    
    log.Printf("Cell A Product Service starting on port %s", service.Port)
    log.Fatal(http.ListenAndServe(":"+service.Port, r))
}
