package main

import (
    "encoding/json"
    "log"
    "net/http"
    "os"
    "os/exec"
    "time"
    "sync"
    "syscall"

    "github.com/prometheus/client_golang/prometheus"
    "github.com/prometheus/client_golang/prometheus/promhttp"
)

var (
    // Backup metrics
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

    backupDuration = prometheus.NewGaugeVec(
        prometheus.GaugeOpts{
            Name: "kopia_backup_duration_seconds",
            Help: "Duration of the last backup in seconds",
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

    // Repository metrics
    repoStatus = prometheus.NewGauge(
        prometheus.GaugeOpts{
            Name: "kopia_repository_status",
            Help: "Repository connection status (0=disconnected, 1=connected)",
        },
    )

    repoSize = prometheus.NewGauge(
        prometheus.GaugeOpts{
            Name: "kopia_repository_size_bytes",
            Help: "Total size of repository in bytes",
        },
    )

    repoFreeSpace = prometheus.NewGauge(
        prometheus.GaugeOpts{
            Name: "kopia_repository_free_space_bytes",
            Help: "Available space in repository",
        },
    )

    // Cache metrics
    cacheSize = prometheus.NewGauge(
        prometheus.GaugeOpts{
            Name: "kopia_cache_size_bytes",
            Help: "Size of Kopia cache in bytes",
        },
    )

    cacheHits = prometheus.NewCounter(
        prometheus.CounterOpts{
            Name: "kopia_cache_hits_total",
            Help: "Total number of cache hits",
        },
    )

    cacheMisses = prometheus.NewCounter(
        prometheus.CounterOpts{
            Name: "kopia_cache_misses_total",
            Help: "Total number of cache misses",
        },
    )
)

func init() {
    // Register backup metrics
    prometheus.MustRegister(backupStatus)
    prometheus.MustRegister(backupSize)
    prometheus.MustRegister(backupDuration)
    prometheus.MustRegister(lastBackupTime)

    // Register repository metrics
    prometheus.MustRegister(repoStatus)
    prometheus.MustRegister(repoSize)
    prometheus.MustRegister(repoFreeSpace)

    // Register cache metrics
    prometheus.MustRegister(cacheSize)
    prometheus.MustRegister(cacheHits)
    prometheus.MustRegister(cacheMisses)
}

type SnapshotInfo struct {
    ID        string    `json:"id"`
    Source    string    `json:"source"`
    StartTime time.Time `json:"startTime"`
    EndTime   time.Time `json:"endTime"`
    Stats     struct {
        TotalSize int64 `json:"totalSize"`
        Files     int   `json:"files"`
    } `json:"stats"`
    Error      string `json:"error,omitempty"`
    Incomplete bool   `json:"incomplete"`
}

type RepositoryInfo struct {
    Status string `json:"status"`
    Size   int64  `json:"size"`
    Cache  struct {
        Size  int64 `json:"size"`
        Hits  int64 `json:"hits"`
        Miss  int64 `json:"miss"`
    } `json:"cache"`
}

func collectMetrics(wg *sync.WaitGroup) {
    defer wg.Done()

    // Collect backup metrics
    if snapshots, err := getSnapshots(); err == nil {
        for _, snapshot := range snapshots {
            source := snapshot.Source
            if snapshot.Error != "" || snapshot.Incomplete {
                backupStatus.WithLabelValues(source).Set(0)
            } else {
                backupStatus.WithLabelValues(source).Set(1)
            }
            backupSize.WithLabelValues(source).Set(float64(snapshot.Stats.TotalSize))
            backupDuration.WithLabelValues(source).Set(snapshot.EndTime.Sub(snapshot.StartTime).Seconds())
            lastBackupTime.WithLabelValues(source).Set(float64(snapshot.EndTime.Unix()))
        }
    }

    // Collect repository metrics
    if repoInfo, err := getRepositoryInfo(); err == nil {
        if repoInfo.Status == "connected" {
            repoStatus.Set(1)
        } else {
            repoStatus.Set(0)
        }
        repoSize.Set(float64(repoInfo.Size))
        
        // Update cache metrics
        cacheSize.Set(float64(repoInfo.Cache.Size))
        cacheHits.Add(float64(repoInfo.Cache.Hits))
        cacheMisses.Add(float64(repoInfo.Cache.Miss))
    }

    // Get repository free space
    if freeSpace, err := getRepositoryFreeSpace(); err == nil {
        repoFreeSpace.Set(float64(freeSpace))
    }
}

func getSnapshots() ([]SnapshotInfo, error) {
    cmd := exec.Command("kopia", "snapshot", "list", "--json")
    output, err := cmd.Output()
    if err != nil {
        return nil, err
    }

    var snapshots []SnapshotInfo
    if err := json.Unmarshal(output, &snapshots); err != nil {
        return nil, err
    }
    return snapshots, nil
}

func getRepositoryInfo() (*RepositoryInfo, error) {
    cmd := exec.Command("kopia", "repository", "status", "--json")
    output, err := cmd.Output()
    if err != nil {
        return nil, err
    }

    var info RepositoryInfo
    if err := json.Unmarshal(output, &info); err != nil {
        return nil, err
    }
    return &info, nil
}

func getRepositoryFreeSpace() (int64, error) {
    repoPath := os.Getenv("KOPIA_REPO_PATH")
    if repoPath == "" {
        repoPath = "/repository"
    }

    var stat syscall.Statfs_t
    if err := syscall.Statfs(repoPath, &stat); err != nil {
        return 0, err
    }

    return int64(stat.Bavail) * int64(stat.Bsize), nil
}

func main() {
    // Configure logging
    log.SetFlags(log.LstdFlags | log.Lshortfile)
    
    // Start metrics collection in background
    go func() {
        for {
            var wg sync.WaitGroup
            wg.Add(1)
            go collectMetrics(&wg)
            wg.Wait()
            time.Sleep(15 * time.Second)
        }
    }()

    // Start HTTP server
    http.Handle("/metrics", promhttp.Handler())
    
    // Add health check endpoint
    http.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
        w.WriteHeader(http.StatusOK)
        w.Write([]byte("OK"))
    })

    port := os.Getenv("KOPIA_EXPORTER_PORT")
    if port == "" {
        port = "9091"
    }

    log.Printf("Starting Kopia exporter on :%s", port)
    if err := http.ListenAndServe(":"+port, nil); err != nil {
        log.Fatal(err)
    }
} 