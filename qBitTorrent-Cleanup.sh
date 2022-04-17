#!/bin/bash

#Config
deleteFiles="false"
torrentPath=/path/to/my/files
qBitTorrentLogPath=/opt/appdata/qbittorrent/config/qBittorrent/logs
LogPath=/var/log/qBitTorrent-Cleanup.log

#Script
dateFormat="%Y-%m-%dT%H:%M:%S"
exec 1>> >(ts '['$dateFormat']' >> "$LogPath") 2>&1
files=`sudo cat $qBitTorrentLogPath/qbittorrent.log | grep "Error: Directory not empty" | awk '{ print $4 }' | tr -s "\'" ' '`
exists=`sudo cat $LogPath | grep "will be deleted" | awk '{ print $2 }' | sed -r 's:^'$torrentPath'/::' | sed 's/.$//'`
array=($files)
value=($exists)

#if [[ " ${array[*]} " =~ " ${value} " ]]; then
#    for i in "${array[@]}"
#        do
#                echo "$torrentPath/$i/ was already deleted"
#        done
#fi

if [[ ! " ${array[*]} " =~ " ${value} " ]]; then
    for i in "${array[@]}"
        do
                echo "$torrentPath/$i/ will be deleted"
                if [ $deleteFiles = "true" ]; then
                rm -rf $torrentPath/$i/
                fi
        done
fi
