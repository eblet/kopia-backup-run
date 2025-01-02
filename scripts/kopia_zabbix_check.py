#!/usr/bin/env python3

import sys
import json
import subprocess
from datetime import datetime

def get_volume_status(volume_path):
    """Check backup status for specific volume"""
    try:
        # Get latest snapshot
        cmd = [
            "docker", "run", "--rm",
            "--network", "host",
            "-v", f"{volume_path}:/backup{volume_path}:ro",
            "-v", f"{HOME}/.config/kopia:/app/config",
            "-v", f"{HOME}/.cache/kopia:/app/cache",
            "kopia/kopia:latest",
            "snapshot", "list",
            f"/backup{volume_path}",
            "--json"
        ]
        
        result = subprocess.run(cmd, capture_output=True, text=True)
        snapshots = json.loads(result.stdout)
        
        if not snapshots:
            return {
                'status': 'failed',
                'last_time': 0,
                'message': 'No snapshots found'
            }
        
        latest = snapshots[-1]
        
        # Check snapshot age
        start_time = datetime.fromisoformat(latest['startTime'].rstrip('Z'))
        age = (datetime.utcnow() - start_time).total_seconds()
        
        # Verify latest snapshot
        verify_cmd = [
            "docker", "run", "--rm",
            "--network", "host",
            "-v", f"{HOME}/.config/kopia:/app/config",
            "-v", f"{HOME}/.cache/kopia:/app/cache",
            "kopia/kopia:latest",
            "snapshot", "verify",
            latest['id']
        ]
        
        verify_result = subprocess.run(verify_cmd, capture_output=True)
        
        return {
            'status': 'success' if verify_result.returncode == 0 else 'failed',
            'last_time': start_time.timestamp(),
            'message': 'Backup verified' if verify_result.returncode == 0 else 'Verification failed'
        }
        
    except Exception as e:
        return {
            'status': 'failed',
            'last_time': 0,
            'message': str(e)
        }

def main():
    if len(sys.argv) < 3:
        print("Usage: kopia_zabbix_check.py [status|validation|last_time] volume_path", file=sys.stderr)
        sys.exit(1)
        
    check_type = sys.argv[1]
    volume_path = sys.argv[2]
    
    result = get_volume_status(volume_path)
    
    if check_type == 'status':
        print(result['status'])
    elif check_type == 'validation':
        print(result['status'])
    elif check_type == 'last_time':
        print(result['last_time'])
    else:
        print(f"Unknown check type: {check_type}", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main() 