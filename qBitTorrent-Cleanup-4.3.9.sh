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
torrentPath=/path/to/downloads
qBitTorrentLogPath=/opt/qbittorrent/config/qBittorrent/logs
logPath=/var/log
qBTlog=qbittorrent.log
qBTClean=qBitTorrent-Cleanup.log
dateFormat=$(date -u +"[%Y-%m-%dT%H:%M:%S]")

# Check for log files
if [ ! -f "$qBitTorrentLogPath/$qBTlog" ]; then
  echo "[WARN] Cannot find $qBTlog. Check the path to your qBitTorrent Logs." 
  exit 1
elif [ ! -r "$qBitTorrentLogPath/$qBTlog" ]; then
  echo "[WARN] Cannot read from $qBTlog. Check permissions."
  exit 1
elif [ ! -f "$logPath/$qBTClean" ]; then
  touch "$logPath/$qBTClean"
elif [ ! -w "$logPath/$qBTClean" ]; then
  echo "[WARN] Cannot write to $logPath/$qBTClean . Check permissions."
  exit 1
fi

# Get the deleted folders from qBittorrent log
folders=$(cat $qBitTorrentLogPath/$qBTlog | grep "Error: Directory not empty" | awk '{ print $4 }' | sed "s/^'//;s/'$//")

# Iterate over the folders and delete if not already deleted
while IFS= read -r folder; do
  if grep -q "$folder" "$logPath/$qBTClean"; then
    continue
  else
    if [ $deleteFiles = "true" ]; then
      if [ -d "$torrentPath/$folder" ]; then
        echo "$dateFormat [INFO] Deleting $torrentPath/$folder" >> "$logPath/$qBTClean"
        rm -r "$torrentPath/$folder"
        if [ $? -eq 0 ]; then
          echo "$dateFormat [INFO] $folder deleted successfully." >> "$logPath/$qBTClean"
        else
          echo "$dateFormat [WARN] $folder not deleted. Possibly file locked." >> "$logPath/$qBTClean"
        fi
      else
        echo "$dateFormat [FLCK] $torrentPath/$folder does not exist." >> "$logPath/$qBTClean"
      fi
    else
      if [ -d "$torrentPath/$folder" ]; then
        echo "$dateFormat [TEST] $folder exists but is INFO only mode" >> "$logPath/$qBTClean"
      else
        echo "$dateFormat [TEST] $folder does not exist in: $torrentPath" >> "$logPath/$qBTClean"
      fi
    fi
  fi
done <<< "$folders"
