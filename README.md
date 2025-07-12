# qBitTorrent Cleanup Script

A Python-based Docker solution to clean up orphaned directories that qBitTorrent fails to delete when using auto-unpackers.

## Background

When using qBitTorrent with auto-unpacking features, it sometimes fails to delete the unpacked files along with their folders when the torrent is deleted. This script monitors your qBitTorrent instance and cleans up these leftover directories.

## Compatibility

- Works with qBitTorrent 4.5+
- Compatible with qBitTorrent 5.x
- Uses the qBitTorrent WebUI API (v2025.5.0)

**Note regarding qBitTorrent 5.x:** While this issue was common in qBitTorrent 4.x versions, it appears to still exist in some scenarios in qBitTorrent 5.x, particularly when using external tools for auto-extraction. A recent GitHub issue (#21550) confirms this problem is still present in version 5.0.0.

## Requirements

- Docker
- Docker Compose
- qBitTorrent with WebUI enabled

## Quick Start

### 1. Clone the repository

```bash
git clone https://github.com/Jarsky/qBitTorrent-Cleanup-Script
cd qBitTorrent-Cleanup-Script
```

### 2. Configure environment variables

Copy the example environment file and edit it with your settings:

```bash
cp env.example.env .env
```

Edit the `.env` file with your qBitTorrent settings:

```
# qBitTorrent WebUI settings
QB_HOST=192.168.1.100
QB_PORT=8080
QB_USERNAME=admin
QB_PASSWORD=yourpassword

# Paths
QB_DOWNLOAD_PATH=/downloads
LOG_FILE=/logs/qbt-cleanup.log

# Script behavior
DRY_RUN=false

# Execution mode: "daemon" or "cron"
EXECUTION_MODE=daemon

# Cron schedule (when EXECUTION_MODE=cron)
CRON_SCHEDULE="0 */4 * * *"
```

### 3. Update the docker-compose.yml file

Edit the `docker-compose.yml` file to map your actual qBitTorrent downloads directory:

```yaml
version: '3'

services:
  qbt-cleanup:
    build: .
    container_name: qbt-cleanup
    volumes:
      - ./logs:/logs
      - /actual/path/to/qbittorrent/downloads:/downloads  # Update this path
    env_file:
      - .env
    restart: unless-stopped
```

Make sure to replace `/actual/path/to/qbittorrent/downloads` with the actual path on your host where qBitTorrent stores downloaded files. This path must match the download path configured in your qBitTorrent settings.

### 4. Build and run with Docker Compose

```bash
docker-compose up -d
```

## Configuration

The following environment variables can be configured in `.env`:

| Variable | Default | Description |
|----------|---------|-------------|
| QB_HOST | localhost | qBitTorrent WebUI host |
| QB_PORT | 8080 | qBitTorrent WebUI port |
| QB_USERNAME | admin | qBitTorrent WebUI username |
| QB_PASSWORD | adminadmin | qBitTorrent WebUI password |
| QB_DOWNLOAD_PATH | /downloads | Path to your qBitTorrent download directory |
| LOG_FILE | /logs/qbt-cleanup.log | Path to log file |
| DRY_RUN | false | Set to true to test without making changes |
| EXECUTION_MODE | daemon | Run mode: "daemon" (continuous) or "cron" (scheduled) |
| SLEEP_INTERVAL | 14400 | Time in seconds between runs when in daemon mode |
| CRON_SCHEDULE | "0 */4 * * *" | Cron expression for scheduling when in cron mode |

## Execution Modes

### Daemon Mode

In daemon mode, the script runs continuously, checking for orphaned directories at regular intervals defined by `SLEEP_INTERVAL`. This is useful when you want to maintain a lightweight, continuously running process.

### Cron Mode

In cron mode, the script runs according to the schedule defined in `CRON_SCHEDULE`. This is useful when you want precise control over when cleanups occur and prefer a scheduled task approach.

## Logging

The script produces detailed logs similar to other torrent management tools, including:

- Script version information
- Connection status and login results
- qBitTorrent version and API version
- Client status (download/upload speeds and totals)
- Number of torrents found
- Details about orphaned directories
- Actions taken (deletions) or simulated actions (in dry run mode)
- Comprehensive error messages

Logs are written both to the console and to the file specified by `LOG_FILE`.

Example log output:
```
Sat, 01 Jun 2024 10:00:01 qbt-cleanup INFO: qBitTorrent Cleanup 1.0.0
Sat, 01 Jun 2024 10:00:01 qbt-cleanup INFO: Starting cleanup process...
Sat, 01 Jun 2024 10:00:01 qbt-cleanup INFO: Connecting to qBitTorrent at 192.168.1.100:8080...
Sat, 01 Jun 2024 10:00:01 qbt-cleanup INFO: Logging in...
Sat, 01 Jun 2024 10:00:01 qbt-cleanup INFO: Login successful. Client is qBitTorrent v5.0.0
Sat, 01 Jun 2024 10:00:01 qbt-cleanup INFO: WebUI API version: 2.8.18
Sat, 01 Jun 2024 10:00:01 qbt-cleanup INFO: Status reported by the client:
Sat, 01 Jun 2024 10:00:01 qbt-cleanup INFO: 	Download Speed: 0.00B/s	Total: 1.25TiB
Sat, 01 Jun 2024 10:00:01 qbt-cleanup INFO: 	Upload Speed: 2.45MiB/s	Total: 10.88TiB
Sat, 01 Jun 2024 10:00:01 qbt-cleanup INFO: Getting all the torrents...
Sat, 01 Jun 2024 10:00:02 qbt-cleanup INFO: Found 157 torrent(s) in the client.
Sat, 01 Jun 2024 10:00:02 qbt-cleanup INFO: Identified 157 unique torrent names
Sat, 01 Jun 2024 10:00:02 qbt-cleanup INFO: Checking download path: /downloads
Sat, 01 Jun 2024 10:00:02 qbt-cleanup INFO: Found 3 orphaned directories
Sat, 01 Jun 2024 10:00:02 qbt-cleanup INFO: Deleting orphaned directory: /downloads/orphaned-folder-1
Sat, 01 Jun 2024 10:00:02 qbt-cleanup INFO: Successfully deleted: /downloads/orphaned-folder-1
```

## Running Without Docker

If you prefer to run without Docker:

1. Install Python 3.7+
2. Install requirements: `pip install -r requirements.txt`
3. Run the script: `python qBitTorrent-Cleanup.py`

### Command line options:

- `--dry-run`: Test mode - doesn't actually delete files
- `--daemon`: Run continuously at specified intervals
- `--interval 3600`: Time in seconds between runs when in daemon mode
- `--run-once`: Run once and exit (for cron scheduling)

## How It Works

The script:
1. Connects to qBitTorrent's WebUI API
2. Gets a list of all current torrents
3. Scans the download directory for folders
4. Removes any folders that don't correspond to current torrents
5. Logs all actions

## Advantages Over Bash Script

- No dependencies on shell utilities or qBitTorrent log files
- Cross-platform compatibility
- Direct API access instead of log parsing
- Better error handling
- Easy configuration via environment variables
- Containerized for easy deployment
- Flexible scheduling options (daemon or cron)
