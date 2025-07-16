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

type User struct {
    ID        string    `json:"id"`
    Name      string    `json:"name"`
    Email     string    `json:"email"`
    CellID    string    `json:"cell_id"`
    CreatedAt time.Time `json:"created_at"`
}

type UserService struct {
    CellID string
    Users  map[string]*User
    mutex  sync.RWMutex
    Port   string
}

func NewUserService() *UserService {
    return &UserService{
        CellID: getEnv("CELL_ID", "cell-a"),
        Users:  make(map[string]*User),
        Port:   getEnv("PORT", "8011"),
    }
}

func getEnv(key, defaultValue string) string {
    if value := os.Getenv(key); value != "" {
        return value
    }
    return defaultValue
}

func (s *UserService) createUser(w http.ResponseWriter, r *http.Request) {
    var user User
    if err := json.NewDecoder(r.Body).Decode(&user); err != nil {
        http.Error(w, "Invalid request body", http.StatusBadRequest)
        return
    }

    s.mutex.Lock()
    defer s.mutex.Unlock()

    user.ID = uuid.New().String()
    user.CellID = s.CellID
    user.CreatedAt = time.Now()
    s.Users[user.ID] = &user

    w.Header().Set("Content-Type", "application/json")
    w.WriteHeader(http.StatusCreated)
    json.NewEncoder(w).Encode(map[string]interface{}{
        "success": true,
        "data":    user,
        "cell_id": s.CellID,
    })
}

func (s *UserService) getUser(w http.ResponseWriter, r *http.Request) {
    vars := mux.Vars(r)
    userID := vars["id"]

    s.mutex.RLock()
    user, exists := s.Users[userID]
    s.mutex.RUnlock()

    w.Header().Set("Content-Type", "application/json")
    if !exists {
        w.WriteHeader(http.StatusNotFound)
        json.NewEncoder(w).Encode(map[string]interface{}{
            "success": false,
            "error":   "User not found",
            "cell_id": s.CellID,
        })
        return
    }

    json.NewEncoder(w).Encode(map[string]interface{}{
        "success": true,
        "data":    user,
        "cell_id": s.CellID,
    })
}

func (s *UserService) getAllUsers(w http.ResponseWriter, r *http.Request) {
    s.mutex.RLock()
    users := make([]*User, 0, len(s.Users))
    for _, user := range s.Users {
        users = append(users, user)
    }
    s.mutex.RUnlock()

    w.Header().Set("Content-Type", "application/json")
    json.NewEncoder(w).Encode(map[string]interface{}{
        "success": true,
        "data":    users,
        "cell_id": s.CellID,
        "count":   len(users),
    })
}

func (s *UserService) updateUser(w http.ResponseWriter, r *http.Request) {
    vars := mux.Vars(r)
    userID := vars["id"]

    var updates User
    if err := json.NewDecoder(r.Body).Decode(&updates); err != nil {
        http.Error(w, "Invalid request body", http.StatusBadRequest)
        return
    }

    s.mutex.Lock()
    defer s.mutex.Unlock()

    user, exists := s.Users[userID]
    if !exists {
        w.WriteHeader(http.StatusNotFound)
        json.NewEncoder(w).Encode(map[string]interface{}{
            "success": false,
            "error":   "User not found",
            "cell_id": s.CellID,
        })
        return
    }

    if updates.Name != "" {
        user.Name = updates.Name
    }
    if updates.Email != "" {
        user.Email = updates.Email
    }

    w.Header().Set("Content-Type", "application/json")
    json.NewEncoder(w).Encode(map[string]interface{}{
        "success": true,
        "data":    user,
        "cell_id": s.CellID,
    })
}

func (s *UserService) deleteUser(w http.ResponseWriter, r *http.Request) {
    vars := mux.Vars(r)
    userID := vars["id"]

    s.mutex.Lock()
    defer s.mutex.Unlock()

    if _, exists := s.Users[userID]; !exists {
        w.WriteHeader(http.StatusNotFound)
        json.NewEncoder(w).Encode(map[string]interface{}{
            "success": false,
            "error":   "User not found",
            "cell_id": s.CellID,
        })
        return
    }

    delete(s.Users, userID)

    w.Header().Set("Content-Type", "application/json")
    json.NewEncoder(w).Encode(map[string]interface{}{
        "success": true,
        "message": "User deleted successfully",
        "cell_id": s.CellID,
    })
}

func (s *UserService) healthCheck(w http.ResponseWriter, r *http.Request) {
    w.Header().Set("Content-Type", "application/json")
    json.NewEncoder(w).Encode(map[string]interface{}{
        "status":     "healthy",
        "service":    "user-service",
        "cell_id":    s.CellID,
        "user_count": len(s.Users),
        "timestamp":  time.Now(),
        "version":    "1.0.0",
    })
}

func main() {
    service := NewUserService()
    
    r := mux.NewRouter()
    
    r.HandleFunc("/health", service.healthCheck).Methods("GET")
    r.HandleFunc("/readiness", service.healthCheck).Methods("GET")
    r.HandleFunc("/users", service.createUser).Methods("POST")
    r.HandleFunc("/users", service.getAllUsers).Methods("GET")
    r.HandleFunc("/users/{id}", service.getUser).Methods("GET")
    r.HandleFunc("/users/{id}", service.updateUser).Methods("PUT")
    r.HandleFunc("/users/{id}", service.deleteUser).Methods("DELETE")
    
    log.Printf("Cell A User Service starting on port %s", service.Port)
    log.Fatal(http.ListenAndServe(":"+service.Port, r))
}