#!/usr/bin/env python3

import os
import json
import time
import logging
import subprocess
from prometheus_client import start_http_server, Gauge, Counter, Info

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger('kopia_exporter')

# Environment variables
KOPIA_CONTAINER = os.getenv('KOPIA_CONTAINER_NAME', 'kopia-server')
EXPORTER_PORT = int(os.getenv('KOPIA_EXPORTER_PORT', '9091'))

# Metrics definition
BACKUP_SIZE = Gauge('kopia_backup_size_bytes', 'Size of latest backup')
BACKUP_FILES = Gauge('kopia_backup_files_total', 'Number of files in latest backup')
BACKUP_AGE = Gauge('kopia_backup_age_seconds', 'Age of latest backup')
REPO_SIZE = Gauge('kopia_repository_size_bytes', 'Total repository size')
REPO_BLOBS = Gauge('kopia_repository_blobs_total', 'Total number of blobs')
BACKUP_ERRORS = Counter('kopia_backup_errors_total', 'Total number of backup errors')
VALIDATION_STATUS = Gauge('kopia_backup_validation', 'Backup validation status (1=success, 0=failed)')
KOPIA_INFO = Info('kopia', 'Kopia version information')

def get_docker_output(command):
    """Execute docker command and return JSON output"""
    try:
        result = subprocess.run(
            f"docker exec {KOPIA_CONTAINER} kopia {command} --json",
            shell=True, capture_output=True, text=True
        )
        return json.loads(result.stdout)
    except Exception as e:
        logger.error(f"Error executing command: {e}")
        BACKUP_ERRORS.inc()
        return None

def collect_metrics():
    """Collect all Kopia metrics"""
    try:
        # Get version info
        version_info = get_docker_output("version")
        if version_info:
            KOPIA_INFO.info({
                'version': version_info.get('version', 'unknown'),
                'build': version_info.get('buildInfo', {}).get('buildVersion', 'unknown')
            })

        # Get snapshot info
        snapshot_data = get_docker_output("snapshot list")
        if snapshot_data:
            latest = sorted(snapshot_data, key=lambda x: x.get('startTime', ''))[-1]
            BACKUP_SIZE.set(latest.get('stats', {}).get('totalSize', 0))
            BACKUP_FILES.set(latest.get('stats', {}).get('totalFiles', 0))
            
            # Calculate age
            start_time = time.mktime(time.strptime(latest['startTime'], '%Y-%m-%dT%H:%M:%S.%fZ'))
            BACKUP_AGE.set(time.time() - start_time)

        # Get repository info
        repo_data = get_docker_output("repository status")
        if repo_data:
            REPO_SIZE.set(repo_data.get('size', 0))
            REPO_BLOBS.set(repo_data.get('blob', {}).get('count', 0))

        # Check validation
        validation = get_docker_output("snapshot verify --all")
        if validation:
            VALIDATION_STATUS.set(1 if validation.get('success') else 0)

    except Exception as e:
        logger.error(f"Error collecting metrics: {e}")
        BACKUP_ERRORS.inc()

def main():
    """Main function"""
    logger.info(f"Starting Kopia exporter on port {EXPORTER_PORT}")
    
    # Start HTTP server
    start_http_server(EXPORTER_PORT)
    
    # Collect metrics every 15 seconds
    while True:
        try:
            collect_metrics()
        except Exception as e:
            logger.error(f"Unexpected error: {e}")
            BACKUP_ERRORS.inc()
        time.sleep(15)

if __name__ == "__main__":
    main() 