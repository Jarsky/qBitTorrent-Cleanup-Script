#!/bin/bash
#########################################################
#                                                       #
#               qBitTorrent-Cleanup script              #
#                                                       #
#        Written by Jarsky ||  Updated 10/05/2022       #
#                                                       #
#   Clean up files not deleted properly by qBittorrent  #
#              if they have been unpacked               #
#                                                       #
# https://github.com/Jarsky/qBitTorrent-Cleanup-Script  #
#                                                       #
#########################################################
#
#Config
deleteFiles="false"
torrentPath=/path/to/downloads
qBitTorrentLogPath=/opt/appdata/qbittorrent/config/qBittorrent/logs
LogPath=/var/log
dependencyCheck="true"
qBTlog=qbittorrent.log
qBTClean=qBitTorrent-Cleanup.log

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

if [ ! -f "$qBitTorrentLogPath/$qBTlog" ]; then
        echo -e "[WARN] Cannot find $qBTlog. Check the path to your qBitTorrent Logs."
        exit 1
        elif [ ! -r "$qBitTorrentLogPath/$qBTlog" ]; then
        echo -e "[WARN] Cannot read from $qBTlog. Check permissions."
        exit 1
        elif [ ! -f "$LogPath/$qBTClean" ]; then
                touch $LogPath/$qBTClean
        elif [ ! -w "$LogPath/$qBTClean" ]; then
        echo -e "[WARN] Cannot write to $LogPath/$qBTClean . Check permissions."
        exit 1
fi

dateFormat="%Y-%m-%dT%H:%M:%S"
exec 1>> >(ts '['$dateFormat']' >> "$LogPath/$qBTClean") 2>&1
#Array lists releases not deleted properly
qBTappLog=`cat $qBitTorrentLogPath/$qBTlog | grep "Error: Directory not empty" | awk '{ print $4 }' | sed "s/^'//;s/'$//"`
qBTappArray=($qBTappLog)
#Array lists files already cleaned up
qBTcleanLog=`cat $LogPath/$qBTClean | grep "\[FLCK\]" | awk '{ print $3 }' | sed -r 's:^'$torrentPath'/::' | sed "s/\/$//"`
qBTcleanArray=($qBTcleanLog)
#Test array
qBTtestLog=`cat $LogPath/$qBTClean | grep "\[TEST\]" | awk '{ print $3 }' | sed -r 's:^'$torrentPath'/::' | sed "s/\/$//"`
qBTtestArray=($qBTtestLog)

for i in "${qBTappArray[@]}";
        do
                if [ $deleteFiles = "true" ]; then
                        if [ -d "$torrentPath/$i" ]; then
                                echo "[INFO] $torrentPath/$i/ will be deleted"
                                deleted=`strace rm -r $torrentPath/$i/ |& grep "+++ exited with" | awk '{print $4}'` #Exit Code: 0=OK 1=Error
                                        if [ $deleted -eq "0" ]; then
                                                echo "[INFO] $i deleted successfully."
                                        elif [ $deleted -eq "1" ]; then
                                                echo "[WARN] $i not deleted. Possibly file locked."
                                        else
                                                echo "[ERROR] $i had an unexpected error."
                                        fi
                        else
                                if [[ ! " ${qBTappArray[*]} " =~ " ${qBTcleanArray[*]} " ]]; then
                                echo "[FLCK] $torrentPath/$i/ doesnt exist."
                                fi
                        fi
                else
                                if [[ ! " ${qBTtestArray[*]} " =~ " ${qBTcleanArray[*]} " ]]; then
                        if [ -d "$torrentPath/$i" ]; then
                                echo "[TEST] $i exists but is INFO only mode"
                        else
                                echo "[TEST] $i doesnt exist in: $torrentPath"
                        fi
                fi
        fi
done
