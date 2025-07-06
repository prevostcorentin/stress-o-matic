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
	"strings"
	"sync"
	"time"
)

// Constantes pour les métriques et les configurations
const (
	helpCPUMetric            = "# HELP cpu_percent CPU usage percent\n"
	typeCPUMetric            = "# TYPE cpu_percent gauge\n"
	helpMemMetric            = "# HELP mem_mb Memory usage in MB\n"
	typeMemMetric            = "# TYPE mem_mb gauge\n"
	contentTypeHeader        = "Content-Type"
	contentTypePlain         = "text/plain"
	successMessage           = "Data received\n"
	defaultPort              = "8080"
	metricsRetentionTime     = -1 * time.Hour
	metricCollectionInterval = 2 * time.Second
	millisecondsMultiplier   = 1000
)

// Structures de données
type StoredData struct {
	ID   int
	Data string
	Time time.Time
}

type MetricSample struct {
	Timestamp  time.Time
	CPUPercent float64
	MemMB      float64
}

type timeRange struct {
	start time.Time
	end   time.Time
}

// Variables globales
var (
	dataStore []StoredData
	dataMu    sync.Mutex

	metrics   []MetricSample
	metricsMu sync.Mutex
)

func main() {
	//go metricsCollector()
	setupHTTPServer()
}

func setupHTTPServer() {
	http.HandleFunc("/data", handlePostData)
	http.HandleFunc("/metrics", handleGetMetrics)

	log.Println("API listening on :" + defaultPort)
	log.Fatal(http.ListenAndServe(":"+defaultPort, nil))
}

// Gestionnaires HTTP
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

	fmt.Printf("Lenght Data : %d\n", len(body))
	storeData(body)
	go processLocalDataCopy()
	sendSuccessResponse(w)
}

func storeData(body []byte) {
	dataMu.Lock()
	defer dataMu.Unlock()

	dataStore = append(dataStore, StoredData{
		ID:   len(dataStore) + 1,
		Data: string(body),
		Time: time.Now(),
	})
	fmt.Printf("Lenght de Datastore : %d\n", len(dataStore))
}

func handleGetMetrics(w http.ResponseWriter, r *http.Request) {
	timeRange, err := parseTimeRange(r)
	if err != nil {
		http.Error(w, "Invalid timestamps", http.StatusBadRequest)
		return
	}

	metricsMu.Lock()
	defer metricsMu.Unlock()

	response := generateMetricsResponse(metrics, timeRange)
	w.Header().Set(contentTypeHeader, contentTypePlain)
	w.WriteHeader(http.StatusOK)
	responseBytes := []byte(response)
	w.Header().Set("Content-Length", strconv.Itoa(len(responseBytes)))
	if _, err := w.Write(responseBytes); err != nil {
		log.Printf("Erreur lors de l'écriture de la réponse : %v", err)
		return
	}
}

// Fonctions utilitaires pour les métriques
func parseTimeRange(r *http.Request) (timeRange, error) {
	startStr := r.URL.Query().Get("start_time")
	endStr := r.URL.Query().Get("end_time")

	start, err1 := strconv.ParseInt(startStr, 10, 64)
	end, err2 := strconv.ParseInt(endStr, 10, 64)

	if err1 != nil || err2 != nil || end <= start {
		return timeRange{}, fmt.Errorf("invalid time range")
	}

	return timeRange{
		start: time.Unix(start, 0),
		end:   time.Unix(end, 0),
	}, nil
}

func generateMetricsResponse(metrics []MetricSample, tr timeRange) string {
	var sb strings.Builder

	sb.WriteString(helpCPUMetric)
	sb.WriteString(typeCPUMetric)
	sb.WriteString(helpMemMetric)
	sb.WriteString(typeMemMetric)

	for _, m := range metrics {
		if !m.Timestamp.Before(tr.start) && !m.Timestamp.After(tr.end) {
			// Conversion en millisecondes
			ts := m.Timestamp.Unix() * millisecondsMultiplier

			// Validation des valeurs
			cpuPercent := math.Max(0, math.Min(100, m.CPUPercent))
			memMB := math.Max(0, m.MemMB)

			// Gestion des erreurs pour Fprintf
			if _, err := fmt.Fprintf(&sb, "cpu_percent %.2f %d\n", cpuPercent, ts); err != nil {
				log.Printf("Erreur lors de l'écriture des métriques CPU : %v", err)
				continue
			}
			if _, err := fmt.Fprintf(&sb, "mem_mb %.2f %d\n", memMB, ts); err != nil {
				log.Printf("Erreur lors de l'écriture des métriques mémoire : %v", err)
				continue
			}
		}
	}

	return sb.String()
}

// Collecte des métriques
func metricsCollector() {
	for {
		updateMetrics()
		cleanupOldMetrics()
		time.Sleep(metricCollectionInterval)
	}
}

func updateMetrics() {
	sample := collectMetrics()
	metricsMu.Lock()
	metrics = append(metrics, sample)
	metricsMu.Unlock()
}

func cleanupOldMetrics() {
	cutoff := time.Now().Add(metricsRetentionTime)
	metricsMu.Lock()
	defer metricsMu.Unlock()

	for len(metrics) > 0 && metrics[0].Timestamp.Before(cutoff) {
		metrics = metrics[1:]
	}
}

func collectMetrics() MetricSample {
	var m runtime.MemStats
	runtime.ReadMemStats(&m)

	return MetricSample{
		Timestamp:  time.Now(),
		CPUPercent: getRealCPUUsage(),
		MemMB:      float64(m.Alloc) / 1024.0 / 1024.0,
	}
}

// Simulation CPU et utilitaires
func cpuBurner() {
	for {
		processLocalDataCopy()
	}
}

func processLocalDataCopy() {
	dataMu.Lock()
	localCopy := make([]StoredData, len(dataStore))
	copy(localCopy, dataStore)
	dataMu.Unlock()

	for _, d := range localCopy {
		_ = heavyCompute(d.Data)
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

func getRealCPUUsage() float64 {
	return rand.Float64()*50 + 20
}

func sendSuccessResponse(w http.ResponseWriter) {
	w.WriteHeader(http.StatusAccepted)
	if _, err := w.Write([]byte(successMessage)); err != nil {
		log.Printf("Erreur lors de l'écriture de la réponse : %v", err)
	}
}
