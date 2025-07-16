FROM golang:1.21-alpine AS builder
WORKDIR /app
COPY go.mod ./
COPY *.go ./
RUN go mod tidy
RUN go build -o order-service main.go

FROM alpine:latest
RUN apk --no-cache add ca-certificates
WORKDIR /root/
COPY --from=builder /app/order-service .
EXPOSE 8021
CMD ["./order-service"]