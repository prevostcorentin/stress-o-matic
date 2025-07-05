BINARY=stress-o-matic
IMAGE=stress-o-matic
PORT=8080

.PHONY: all build run docker-build docker-run clean

all: build

build:
	go build -o $(BINARY) main.go

run:
	./$(BINARY)

docker-build:
	docker build -t $(IMAGE) .

docker-run:
	docker run --rm -p $(PORT):$(PORT) $(IMAGE)

clean:
	rm -f $(BINARY)
	docker rmi $(IMAGE) || true
