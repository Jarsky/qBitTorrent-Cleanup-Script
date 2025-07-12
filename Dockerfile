FROM python:3.11-slim

WORKDIR /app

# Install cron and other dependencies
RUN apt-get update && \
    apt-get install -y cron && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application
COPY qBitTorrent-Cleanup.py .
COPY entrypoint.sh .
RUN chmod +x qBitTorrent-Cleanup.py entrypoint.sh

# Create volumes
VOLUME /logs
VOLUME /downloads

# Entry point
ENTRYPOINT ["/app/entrypoint.sh"] 