#!/bin/bash
#############################################################
#                                                                  
#               qBitTorrent-Cleanup script                         
#                                                                  
#        Written by Jarsky || v1.2 Rewritten to be more efficient       
#                                                                  
#   Clean up files not deleted properly by qBittorrent  
#              if they have been unpacked               
#                                                       
# https://github.com/Jarsky/qBitTorrent-Cleanup-Script  
#                                                       
###############################################################
#
# Config
deleteFiles="false"
torrentPath="/path/to/downloads"
qBitTorrentLogPath="/opt/qbittorrent/config/qBittorrent/logs"
logPath="/var/log"
qBTlog="qbittorrent.log"
qBTClean="qBitTorrent-Cleanup.log"

# Script
dateFormat=$(date -u +"[%Y-%m-%dT%H:%M:%S]")

if [ ! -f "$qBitTorrentLogPath/$qBTlog" ]; then
  echo "$dateFormat [WARN] Cannot find $qBTlog. Check the path to your qBitTorrent Logs."
  exit 1
elif [ ! -r "$qBitTorrentLogPath/$qBTlog" ]; then
  echo "$dateFormat [WARN] Cannot read from $qBTlog. Check permissions."
  exit 1
elif [ ! -f "$logPath/$qBTClean" ]; then
  touch "$logPath/$qBTClean"
elif [ ! -w "$logPath/$qBTClean" ]; then
  echo "$dateFormat [WARN] Cannot write to $logPath/$qBTClean . Check permissions."
  exit 1
fi

# Get the deleted folders from qBittorrent log
folders=$(cat $qBitTorrentLogPath/$qBTlog | grep "Error: Directory not empty" | awk '{ print $4 }' | sed "s/^'//;s/'$//")

# Iterate over the folders and delete if not already deleted
while IFS= read -r folder; do
  if grep -q "$folder" "$logPath/$qBTClean"; then
    continue
  else
    if [ "$deleteFiles" = "true" ]; then
      rm -rf "$torrentPath/$folder"
      echo "$dateFormat [INFO] Deleted $folder" >> "$logPath/$qBTClean"
    fi
    echo "$dateFormat [TEST] Deleted $folder" >> "$logPath/$qBTClean"
  fi
done <<< "$folders"
