package main

import (
    "encoding/json"
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

    backupSize = prometheus.NewGaugeVec(
        prometheus.GaugeOpts{
            Name: "kopia_backup_size_bytes",
            Help: "Size of the last backup in bytes",
        },
        []string{"source"},
    )

    lastBackupTime = prometheus.NewGaugeVec(
        prometheus.GaugeOpts{
            Name: "kopia_last_backup_timestamp",
            Help: "Timestamp of the last backup",
        },
        []string{"source"},
    )
)

func init() {
    prometheus.MustRegister(backupStatus)
    prometheus.MustRegister(backupSize)
    prometheus.MustRegister(lastBackupTime)
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
        output, err := cmd.Output()
        if err != nil {
            log.Printf("Error executing kopia: %v", err)
            time.Sleep(60 * time.Second)
            continue
        }

        var snapshots []map[string]interface{}
        if err := json.Unmarshal(output, &snapshots); err != nil {
            log.Printf("Error parsing JSON: %v", err)
            time.Sleep(60 * time.Second)
            continue
        }

        for _, snapshot := range snapshots {
            source := snapshot["source"].(string)
            stats := snapshot["stats"].(map[string]interface{})
            
            // Update metrics
            backupStatus.WithLabelValues(source).Set(1)
            backupSize.WithLabelValues(source).Set(stats["totalSize"].(float64))
            
            if startTime, ok := snapshot["startTime"].(string); ok {
                if t, err := time.Parse(time.RFC3339, startTime); err == nil {
                    lastBackupTime.WithLabelValues(source).Set(float64(t.Unix()))
                }
            }
        }

        time.Sleep(60 * time.Second)
    }
}
