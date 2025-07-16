FROM golang:1.21-alpine AS builder
WORKDIR /app
COPY go.mod ./
COPY *.go ./
RUN go mod tidy
RUN go build -o payment-service main.go

FROM alpine:latest
RUN apk --no-cache add ca-certificates
WORKDIR /root/
COPY --from=builder /app/payment-service .
EXPOSE 8022
CMD ["./payment-service"]
