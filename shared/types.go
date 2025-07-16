package shared

import "time"

type User struct {
    ID        string    `json:"id"`
    Name      string    `json:"name"`
    Email     string    `json:"email"`
    CellID    string    `json:"cell_id"`
    CreatedAt time.Time `json:"created_at"`
}

type Product struct {
    ID          string    `json:"id"`
    Name        string    `json:"name"`
    Description string    `json:"description"`
    Price       float64   `json:"price"`
    Stock       int       `json:"stock"`
    CellID      string    `json:"cell_id"`
    CreatedAt   time.Time `json:"created_at"`
}

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

type Payment struct {
    ID        string    `json:"id"`
    OrderID   string    `json:"order_id"`
    Amount    float64   `json:"amount"`
    Status    string    `json:"status"`
    Method    string    `json:"method"`
    CellID    string    `json:"cell_id"`
    CreatedAt time.Time `json:"created_at"`
}

type ServiceResponse struct {
    Success bool        `json:"success"`
    Data    interface{} `json:"data,omitempty"`
    Error   string      `json:"error,omitempty"`
    CellID  string      `json:"cell_id"`
}