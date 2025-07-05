package main

import (
	"fmt"
	"io"
	"log"
	"math"
	"math/rand"
	"net/http"
	"runtime"
	"strconv"
	"sync"
	"time"
)

type StoredData struct {
	ID   int
	Data string
	Time time.Time
}

var (
	dataStore []StoredData
	dataMu    sync.Mutex

	metrics   []MetricSample
	metricsMu sync.Mutex
)

type MetricSample struct {
	Timestamp  time.Time
	CPUPercent float64
	MemMB      float64
}

func main() {
	go metricsCollector()
	go cpuBurner() // 👈 Runs forever

	http.HandleFunc("/data", handlePostData)
	http.HandleFunc("/metrics", handleGetMetrics)

	port := "8080"
	log.Println("API listening on :" + port)
	log.Fatal(http.ListenAndServe(":"+port, nil))
}

func handlePostData(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Only POST supported", http.StatusMethodNotAllowed)
		return
	}

	body, err := io.ReadAll(r.Body)
	if err != nil {
		http.Error(w, "Failed to read body", http.StatusBadRequest)
		return
	}

	dataMu.Lock()
	dataStore = append(dataStore, StoredData{
		ID:   len(dataStore) + 1,
		Data: string(body),
		Time: time.Now(),
	})
	dataMu.Unlock()

	w.WriteHeader(http.StatusAccepted)
	w.Write([]byte("Data received\n"))
}

func handleGetMetrics(w http.ResponseWriter, r *http.Request) {
	startStr := r.URL.Query().Get("start_time")
	endStr := r.URL.Query().Get("end_time")

	start, err1 := strconv.ParseInt(startStr, 10, 64)
	end, err2 := strconv.ParseInt(endStr, 10, 64)
	if err1 != nil || err2 != nil || end <= start {
		http.Error(w, "Invalid timestamps", http.StatusBadRequest)
		return
	}

	startTime := time.Unix(start, 0)
	endTime := time.Unix(end, 0)

	metricsMu.Lock()
	defer metricsMu.Unlock()

	var resp string
	resp += "# HELP cpu_percent CPU usage percent\n"
	resp += "# TYPE cpu_percent gauge\n"
	resp += "# HELP mem_mb Memory usage in MB\n"
	resp += "# TYPE mem_mb gauge\n"

	for _, m := range metrics {
		if m.Timestamp.After(startTime) && m.Timestamp.Before(endTime) {
			ts := m.Timestamp.Unix()
			resp += fmt.Sprintf("cpu_percent %f %d\n", m.CPUPercent, ts*1000)
			resp += fmt.Sprintf("mem_mb %f %d\n", m.MemMB, ts*1000)
		}
	}

	w.Header().Set("Content-Type", "text/plain")
	w.Write([]byte(resp))
}

func cpuBurner() {
	for {
		dataMu.Lock()
		localCopy := make([]StoredData, len(dataStore))
		copy(localCopy, dataStore)
		dataMu.Unlock()

		for _, d := range localCopy {
			// Compute-heavy manipulation
			// Example: Hashing the content repeatedly
			_ = heavyCompute(d.Data)
		}
	}
}

func heavyCompute(input string) float64 {
	acc := 0.0
	for i := 0; i < len(input)*1000; i++ {
		v := float64(i) + float64(input[i%len(input)])
		acc += math.Sqrt(v) * math.Sin(v) * math.Cos(v)
	}
	return acc
}

func metricsCollector() {
	for {
		sample := collectMetrics()
		metricsMu.Lock()
		metrics = append(metrics, sample)
		metricsMu.Unlock()

		// Keep last 1 hour of samples
		cutoff := time.Now().Add(-1 * time.Hour)
		metricsMu.Lock()
		for len(metrics) > 0 && metrics[0].Timestamp.Before(cutoff) {
			metrics = metrics[1:]
		}
		metricsMu.Unlock()

		time.Sleep(2 * time.Second)
	}
}

func collectMetrics() MetricSample {
	var m runtime.MemStats
	runtime.ReadMemStats(&m)

	cpuPercent := getRealCPUUsage() // 🔥 You'll write this
	memMB := float64(m.Alloc) / 1024.0 / 1024.0

	return MetricSample{
		Timestamp:  time.Now(),
		CPUPercent: cpuPercent,
		MemMB:      memMB,
	}
}

func getRealCPUUsage() float64 {
	// Stub. Write your /proc/stat parser here.
	return rand.Float64()*50 + 20
}
