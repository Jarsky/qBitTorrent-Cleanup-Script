#!/bin/bash

#Config
deleteFiles="false"
torrentPath=/path/to/my/files
qBitTorrentLogPath=/opt/appdata/qbittorrent/config/qBittorrent/logs
LogPath=/var/log/qBitTorrent-Cleanup.log
dependencyCheck="true"

#Functions
function fCheckOS() {
        if [ -f /etc/lsb-release ]; then
            . /etc/lsb-release
                OS=$DISTRIB_ID
                VER=$DISTRIB_RELEASE
        elif [ -f /etc/debian_version ]; then
                OS=Debian
                VER=$(cat /etc/debian_version)
        elif [ -f /etc/redhat-release ]; then
                OS=CentOS
                VER=$(rpm -qa \*-release | grep -Ei "oracle|redhat|centos" | cut -d"-" -f3)
        else
                OS=$(uname -s)
                VER=$(uname -r)
        fi
}

function fDependencies() {
                RED='\033[0;31m'
                YEL='\033[1;33m'
                GRN='\033[0;32m'
                NC='\033[0m'
        if [ $OS = "Ubuntu" ] && [ $(dpkg-query -W -f='${Status}' moreutils 2>/dev/null | grep -c "ok installed") -eq 0 ]; then
                        if [ "$EUID" -ne 0 ]; then
                        echo -e "${YEL}You are missing moreutils which will break the script${NC}\n"
                        echo -e "${YEL}You must run as ${RED}sudo${YEL} for first run e.g sudo ${BASH_SOURCE[0]}${NC}\n"
                        exit 0
                        fi
                        apt-get -y install moreutils
                        echo ""
                        echo -e "${GRN}You can now start the script normally using ${BASH_SOURCE[0]}${NC}\n"
                        echo ""
                        exit 0

        elif [ $OS = "CentOS" ] && [ yum -q list installed moreutils &>/dev/null && echo "Error" ]; then
                        if [ "$EUID" -ne 0 ]; then
                        echo -e "${YEL}You are missing moreutils which will break the script${NC}\n"
                        echo -e "${YEL}You must run as ${RED}sudo${YEL} for first run e.g sudo ${BASH_SOURCE[0]}${NC}\n"
                        exit 0
                        fi
                        yum -y install moreutils
                        echo ""
                        echo -e "${GRN}You can now start the script normally using ${BASH_SOURCE[0]}${NC}\n"
                        echo ""
                        exit 0
        fi
}

#Script
if [ $dependencyCheck = "true" ]; then
fCheckOS;
fDependencies;
fi

if [ ! -f "$qBitTorrentLogPath/qbittorrent.log" ]; then
        echo -e "[WARN] Cannot find qbittorrent.log. Check your Log Path"
        exit 1
fi

dateFormat="%Y-%m-%dT%H:%M:%S"
exec 1>> >(ts '['$dateFormat']' >> "$LogPath") 2>&1
files=`cat $qBitTorrentLogPath/qbittorrent.log | grep "Error: Directory not empty" | awk '{ print $4 }' | tr -s "\'" ' '`
exists=`cat $LogPath | grep "will be deleted" | awk '{ print $3 }' | sed -r 's:^'$torrentPath'/::' | sed 's/.$//'`
array=($files)
value=($exists)

#if [[ " ${array[*]} " =~ " ${value} " ]]; then
#    for i in "${array[@]}"
#        do
#                echo "[INFO] $torrentPath/$i/ was already deleted"
#        done
#fi

if [[ ! " ${array[*]} " =~ " ${value} " ]]; then

    for i in "${array[@]}"
        do
                if [ $deleteFiles = "true" ]; then
                echo "[INFO] $torrentPath/$i/ will be deleted"
                rm -rf $torrentPath/$i/
                else
                echo "[WARN] $torrentPath/$i/ will be deleted (TEST :: DELETE MANUALLY)"
                fi
        done
fi
