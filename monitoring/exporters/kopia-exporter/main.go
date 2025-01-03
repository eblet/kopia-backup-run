package main

import (
    "log"
    "net/http"
    "os/exec"
    "time"

    "github.com/prometheus/client_golang/prometheus"
    "github.com/prometheus/client_golang/prometheus/promhttp"
)

var (
    backupStatus = prometheus.NewGaugeVec(
        prometheus.GaugeOpts{
            Name: "kopia_backup_status",
            Help: "Status of the last backup (0=error, 1=success)",
        },
        []string{"source"},
    )
)

func init() {
    prometheus.MustRegister(backupStatus)
}

func main() {
    http.Handle("/metrics", promhttp.Handler())
    go collectMetrics()
    log.Printf("Starting Kopia exporter on :9091")
    log.Fatal(http.ListenAndServe(":9091", nil))
}

func collectMetrics() {
    for {
        cmd := exec.Command("kopia", "snapshot", "list", "--json")
        if err := cmd.Run(); err != nil {
            log.Printf("Error executing kopia: %v", err)
            backupStatus.WithLabelValues("default").Set(0)
        } else {
            backupStatus.WithLabelValues("default").Set(1)
        }
        time.Sleep(60 * time.Second)
    }
} 