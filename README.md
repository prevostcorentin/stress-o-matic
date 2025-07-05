# stress-o-matic

**The controlled chaos engine for your benchmarking pleasure**

stress-o-matic is a minimalist HTTP API designed to generate real CPU and memory load by continuously manipulating user-provided data in memory. Born from the depths of Docker vs LXC benchmarking wars, it serves one purpose: help you measure system stability and performance under genuine stress — no synthetic smoke and mirrors.

## Features

- **POST /data** — feed it data, and it keeps crunching, hashing, and torturing your CPU non-stop  
- **GET /metrics?start_time=...&end_time=...** — retrieve real CPU and memory usage metrics in a Prometheus-friendly format  
- Lightweight and intentionally simple: built for benchmarks, not production  
-  Written in Go, because why not burn CPU with style?

## Why stress-o-matic?

Benchmarking container runtimes demands realistic workloads that touch both CPU and RAM — stress-o-matic delivers exactly that by working on your data endlessly. It’s your humble servant in the quest to understand how well your environment handles stress, chaos, and eventual fan-induced screams.

## Getting started

```bash
go run main.go
```

Feed it data

```bash
curl -X POST http://localhost:8080/data -d "some big juicy data payload"
```

Grab metrics from your favorite time window:

```bash
curl "http://localhost:8080/metrics?start_time=1620000000&end_time=1620003600"
```

## Disclaimer

`stress-o-matic` is garbage code mostly AI-written: built for chaos and scientific curiosity. It is not meant to be clean nor maintainable; but to be used responsibly or just for fun. Your fans may beg for mercy; don't.

Happy benchmarking! 🚀🔥
