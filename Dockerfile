# Build stage
FROM golang:1.21-alpine AS builder

WORKDIR /app

# Copy source
COPY main.go .

# Build a static binary with no cgo
RUN CGO_ENABLED=0 GOOS=linux go build -o stress-o-matic main.go

# Final stage - minimal image
FROM scratch

# Copy the binary
COPY --from=builder /app/stress-o-matic /stress-o-matic

# Expose the port used by the app
EXPOSE 8080

# Run the binary
ENTRYPOINT ["/stress-o-matic"]
