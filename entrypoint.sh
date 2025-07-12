#!/bin/bash
set -e

# Create log directory if it doesn't exist
mkdir -p "$(dirname "$LOG_FILE")"

# Function to setup and start cron
setup_cron() {
    # Create the crontab file
    echo "Setting up cron with schedule: $CRON_SCHEDULE"
    echo "$CRON_SCHEDULE python /app/qBitTorrent-Cleanup.py --run-once >> $LOG_FILE 2>&1" > /etc/cron.d/qbt-cleanup
    
    # Give execution rights on the cron job
    chmod 0644 /etc/cron.d/qbt-cleanup
    
    # Apply cron job
    crontab /etc/cron.d/qbt-cleanup
    
    echo "Cron job installed. Starting cron..."
    
    # Start cron in the foreground
    cron -f
}

# Check execution mode
case "$EXECUTION_MODE" in
    "cron")
        setup_cron
        ;;
    *)
        # Default is daemon mode
        echo "Starting in daemon mode with interval: $SLEEP_INTERVAL seconds"
        exec python /app/qBitTorrent-Cleanup.py --daemon --interval "$SLEEP_INTERVAL"
        ;;
esac 