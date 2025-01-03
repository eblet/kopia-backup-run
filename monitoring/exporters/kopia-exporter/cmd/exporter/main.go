package main

import (
    "encoding/json"
    "log"
    "net/http"
    "os"
    "os/exec"
    "path/filepath"
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

    repoStatus = prometheus.NewGauge(
        prometheus.GaugeOpts{
            Name: "kopia_repository_status",
            Help: "Repository connection status (0=disconnected, 1=connected)",
        },
    )
)

func init() {
    prometheus.MustRegister(backupStatus)
    prometheus.MustRegister(backupSize)
    prometheus.MustRegister(lastBackupTime)
    prometheus.MustRegister(repoStatus)
}

type SnapshotInfo struct {
    ID        string    `json:"id"`
    Source    string    `json:"source"`
    StartTime time.Time `json:"startTime"`
    EndTime   time.Time `json:"endTime"`
    Size      int64     `json:"size"`
}

func setupKopiaConfig() error {
    configDir := os.Getenv("KOPIA_CONFIG_PATH")
    if configDir == "" {
        configDir = "/app/config"
    }

    // Create base directories
    dirs := []string{
        configDir,
        os.Getenv("KOPIA_CACHE_DIRECTORY"),
        "/app/logs",
    }

    for _, dir := range dirs {
        if dir != "" {
            if err := os.MkdirAll(dir, 0755); err != nil {
                return err
            }
        }
    }

    // Set env variables
    os.Setenv("KOPIA_CONFIG_PATH", filepath.Join(configDir, "repository.config"))

    return nil
}

func main() {
    if err := setupKopiaConfig(); err != nil {
        log.Fatalf("Error setting up config: %v", err)
    }

    // Get connection parameters from env variables
    serverURL := os.Getenv("KOPIA_SERVER_URL")
    if serverURL == "" {
        serverURL = "http://kopia-server:51515"
    }

    password := os.Getenv("KOPIA_PASSWORD")
    if password == "" {
        log.Fatal("KOPIA_PASSWORD environment variable is required")
    }

    // Check connection to server
    connectCmd := exec.Command("kopia", "repository", "connect", "server",
        "--url", serverURL,
        "--password", password,
        "--no-check-for-updates",
        "--config-file", filepath.Join(os.Getenv("KOPIA_CONFIG_PATH"), "repository.config"),
        "--cache-directory", os.Getenv("KOPIA_CACHE_DIRECTORY"),
        "--persist-credentials")

    if output, err := connectCmd.CombinedOutput(); err != nil {
        log.Printf("Error connecting to Kopia server: %v\nOutput: %s", err, output)
        repoStatus.Set(0)
    } else {
        log.Printf("Successfully connected to Kopia server")
        repoStatus.Set(1)
    }

    http.Handle("/metrics", promhttp.Handler())
    go collectMetrics()
    log.Printf("Starting Kopia exporter on :9091")
    log.Fatal(http.ListenAndServe(":9091", nil))
}

func collectMetrics() {
    for {
        cmd := exec.Command("kopia", "snapshot", "list", "--json", "--no-progress")
        output, err := cmd.CombinedOutput()
        if err != nil {
            log.Printf("Error executing kopia: %v\nOutput: %s", err, output)
            backupStatus.WithLabelValues("default").Set(0)
            repoStatus.Set(0)
        } else {
            var snapshots []SnapshotInfo
            if err := json.Unmarshal(output, &snapshots); err != nil {
                log.Printf("Error parsing JSON: %v", err)
                continue
            }

            repoStatus.Set(1)
            // Process each snapshot
            for _, snapshot := range snapshots {
                source := snapshot.Source
                backupStatus.WithLabelValues(source).Set(1)
                backupSize.WithLabelValues(source).Set(float64(snapshot.Size))
                lastBackupTime.WithLabelValues(source).Set(float64(snapshot.EndTime.Unix()))
            }
        }
        time.Sleep(60 * time.Second)
    }
} 