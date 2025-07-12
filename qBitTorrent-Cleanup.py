#!/usr/bin/env python3
import os
import logging
import time
import argparse
import shutil
from datetime import datetime
import sys
import qbittorrentapi

# Script version
VERSION = "1.0.0"

# Configure logging
logging_format = '%(asctime)s %(name)s %(levelname)s: %(message)s'
logging_datefmt = '%a, %d %b %Y %H:%M:%S'

logging.basicConfig(
    level=logging.INFO,
    format=logging_format,
    datefmt=logging_datefmt,
    handlers=[
        logging.FileHandler(os.environ.get("LOG_FILE", "/logs/qbt-cleanup.log")),
        logging.StreamHandler()
    ]
)
log = logging.getLogger("qbt-cleanup")

def main():
    # Parse arguments
    parser = argparse.ArgumentParser(description='Clean up incomplete qBitTorrent deletions')
    parser.add_argument('--dry-run', action='store_true', help='Test mode - no actual deletions')
    parser.add_argument('--interval', type=int, default=int(os.environ.get('SLEEP_INTERVAL', 14400)), 
                       help='Interval in seconds between cleanup runs when in daemon mode')
    parser.add_argument('--daemon', action='store_true', help='Run continuously at specified intervals')
    parser.add_argument('--run-once', action='store_true', help='Run once and exit (for cron mode)')
    args = parser.parse_args()

    # Get dry run from environment if not set via command line
    dry_run = args.dry_run or os.environ.get('DRY_RUN', '').lower() in ('true', '1', 'yes')

    # Print version info
    log.info(f"qBitTorrent Cleanup {VERSION}")
    
    # Run loop
    while True:
        try:
            log.info("Starting cleanup process...")
            cleanup(dry_run)
        except Exception as e:
            log.error(f"Unexpected error during cleanup: {str(e)}")
        
        if args.run_once or not args.daemon:
            break
        
        log.info(f"Sleeping for {args.interval} seconds...")
        time.sleep(args.interval)

def cleanup(dry_run=False):
    # Connect to qBitTorrent API
    host = os.environ.get('QB_HOST', 'localhost')
    port = int(os.environ.get('QB_PORT', 8080))
    username = os.environ.get('QB_USERNAME', 'admin')
    password = os.environ.get('QB_PASSWORD', 'adminadmin')
    
    log.info(f"Connecting to qBitTorrent at {host}:{port}...")
    
    try:
        # Initialize qBittorrent Client
        qbt = qbittorrentapi.Client(
            host=host,
            port=port,
            username=username,
            password=password
        )
        
        # Connect and log in
        log.info("Logging in...")
        qbt.auth_log_in()
        
        # Get qBitTorrent version info
        qbt_version = qbt.app.version
        api_version = qbt.app.web_api_version
        log.info(f"Login successful. Client is qBitTorrent v{qbt_version}")
        log.info(f"WebUI API version: {api_version}")
        
        # Get client status
        transfer_info = qbt.transfer.info
        dl_speed = format_size(transfer_info.dl_info_speed)
        ul_speed = format_size(transfer_info.up_info_speed)
        dl_total = format_size(transfer_info.dl_info_data)
        ul_total = format_size(transfer_info.up_info_data)
        
        log.info(f"Status reported by the client:")
        log.info(f"\tDownload Speed: {dl_speed}/s\tTotal: {dl_total}")
        log.info(f"\tUpload Speed: {ul_speed}/s\tTotal: {ul_total}")
        
        # Get the torrents that still exist
        log.info("Getting all the torrents...")
        torrents = qbt.torrents.info()
        
        if not torrents:
            log.info("No torrents found in qBitTorrent.")
            return
        
        torrent_count = len(torrents)
        log.info(f"Found {torrent_count} torrent(s) in the client.")
        
        current_torrents = {t.name for t in torrents}
        log.info(f"Identified {len(current_torrents)} unique torrent names")
        
        # Find directories in download path that aren't associated with current torrents
        download_path = os.environ.get('QB_DOWNLOAD_PATH', '/downloads')
        log.info(f"Checking download path: {download_path}")
        
        if not os.path.exists(download_path):
            log.error(f"Download path does not exist: {download_path}")
            return
        
        orphaned_dirs = []
        
        try:
            for item in os.listdir(download_path):
                full_path = os.path.join(download_path, item)
                if os.path.isdir(full_path) and item not in current_torrents:
                    orphaned_dirs.append((item, full_path))
        except Exception as e:
            log.error(f"Error scanning download directory: {str(e)}")
            return
        
        if not orphaned_dirs:
            log.info("No orphaned directories found.")
            return
        
        log.info(f"Found {len(orphaned_dirs)} orphaned director{('y' if len(orphaned_dirs) == 1 else 'ies')}")
        
        # Process orphaned directories
        for name, path in orphaned_dirs:
            if dry_run:
                log.info(f"Would delete orphaned directory: {path}")
            else:
                try:
                    log.info(f"Deleting orphaned directory: {path}")
                    shutil.rmtree(path)
                    log.info(f"Successfully deleted: {path}")
                except Exception as e:
                    log.error(f"Failed to delete {path}: {str(e)}")
        
    except qbittorrentapi.LoginFailed as e:
        log.error(f"Failed to login to qBitTorrent: {str(e)}")
    except qbittorrentapi.APIConnectionError as e:
        log.error(f"Failed to connect to qBitTorrent API: {str(e)}")
    except qbittorrentapi.APIError as e:
        log.error(f"qBitTorrent API error: {str(e)}")
    except Exception as e:
        log.error(f"Unexpected error: {str(e)}")
    finally:
        try:
            qbt.auth_log_out()
            log.info("Logged out from qBitTorrent")
        except:
            pass

def format_size(size_bytes):
    """Format bytes into human readable format"""
    if size_bytes == 0:
        return "0.00B"
    
    size_names = ("B", "KiB", "MiB", "GiB", "TiB", "PiB")
    i = 0
    while size_bytes >= 1024 and i < len(size_names) - 1:
        size_bytes /= 1024
        i += 1
    
    return f"{size_bytes:.2f}{size_names[i]}"

if __name__ == "__main__":
    main() 