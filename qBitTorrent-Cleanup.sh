#!/bin/bash
####################################################################################################
#
#       qBitTorrent-Cleanup by Jarsky
#
#       Updated:  21/01/2023
#       Version:  v1.5
#
#       Summary:
#           This script is intended for qBitTorrent 4.5+
#           Using an auto unpacker, qBitTorrent isnt able to delete the unpacked files along with
#           its folder. This script will check the qBitTorrent log and then do comparisons
#
#       Pre-requisites:
#           Install qbittorrent-cli:  https://github.com/fedarovich/qbittorrent-cli
#           Setup an SSH key: https://phoenixnap.com/kb/setup-passwordless-ssh
#           Install jq: apt install -y jq
#
#       Usage:
#           ./qBitTorrent-Cleanup.sh --help         Shows all commands
#
#       More Support at: https://github.com/Jarsky/qBitTorrent-Cleanup-Script
#
#####################################################################################################

#Check your Configurations here

torrentPath=/path/to/downloads
qBitTorrentLog=/opt/qbittorrent/config/qBittorrent/logs/qbittorrent.log
logFile=/var/log/qBitTorrent-Cleanup.log
dependencyCheck="true"
jsonFilename=qbt.json
qbtcliSettings=~/.qbt/settings.json


###### You shouldnt need to edit below this line ######
#######################################################

Name=qBitTorrent-Cleanup
version=1.5

dateFormat() {
    date +"[%Y-%m-%d %H:%M:%S]"
}

# Color codes
if [[ -t 1 ]]; then
   RED=$(tput setaf 1)
   GRN=$(tput setaf 2)
   YEL=$(tput setaf 3)
   WHITE=$(tput setaf 7)
   TEAL=$(tput setaf 6)
   MAGENTA=$(tput setaf 5)
   RESET=$(tput sgr0)
fi

# Logging levels
ERROR="${RED}[ERROR]${RESET}"
WARN="${YEL}[WARN]${RESET}"
INFO="${TEAL}[INFO]${RESET}"
TEST="${MAGENTA}[INFO]${RESET}"

#Functions
function checkOS() {
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

function checkDependencies() {
        if [ $OS = "Ubuntu" ] && [ $(dpkg-query -W -f='${Status}' moreutils 2>/dev/null | grep -c "ok installed") -eq 0 ]; then
                        if [ "$EUID" -ne 0 ]; then
                        echo -e "${YEL}You are missing moreutils which will break the script${RESET}\n"
                        echo -e "${YEL}You must run as ${RED}sudo${YEL} for first run e.g sudo ${BASH_SOURCE[0]}${RESET}\n"
                        exit 0
                        fi
                        apt-get -y install moreutils
                        echo ""
                        echo -e "${GRN}You can now start the script normally using ${BASH_SOURCE[0]}${RESET}\n"
                        echo ""
                        exit 0

        elif [ $OS = "CentOS" ] && [ yum -q list installed moreutils &>/dev/null && echo "Error" ]; then
                        if [ "$EUID" -ne 0 ]; then
                        echo -e "${YEL}You are missing moreutils which will break the script${RESET}\n"
                        echo -e "${YEL}You must run as ${RED}sudo${YEL} for first run e.g sudo ${BASH_SOURCE[0]}${RESET}\n"
                        exit 0
                        fi
                        yum -y install moreutils
                        echo ""
                        echo -e "${GRN}You can now start the script normally using ${BASH_SOURCE[0]}${RESET}\n"
                        echo ""
                        exit 0
        fi
}


#### General Messages
function helpCMD(){
        echo -e "${TEAL}$Name${RESET} | ${YEL}Version:${RESET} $version | ${RED}Repo:${RESET} https://github.com/Jarsky/qBitTorrent-Cleanup-Script

        Help [ -h | --help ]
        Version [ -v | --version ]

        Usage $0 [-command] [arg]

        Commands:

        #WIP -run                        Will use the new qBitTorrent CLI mode
        #WIP -run test                   Will run checks in Read-Only mode

        -legacy                     Will use 'legacy' mode
        -legacy test                Will use 'legacy' mode

        -cron                       Will show CRON options"
        echo -e ""
}

function versionCMD(){
        echo -e ""
        echo -e "${TEAL}$Name${RESET} | ${YEL}Version:${RESET} $version | ${RED}Repo:${RESET} https://github.com/Jarsky/qBitTorrent-Cleanup-Script

        ${MAGENTA}Author${RESET}: Jarsky
        ${MAGENTA}Update 1.5${RESET}: Moved original logic into 'legacy' mode, in favor of qBitTorrent-CLI comparison
        ${MAGENTA}Update 1.4${RESET}: Refactored code and added functions
        ${MAGENTA}Update 1.3${RESET}: Changed logging so doesnt require package"
        echo -e ""
}

function qbtcliCheck() {
    if [ ! -f $qbtcliSettings ]; then
        echo -e "$(dateFormat) ${WARN} The qBitTorrent CLI settings file hasn't been configured."
        echo -e "$(dateFormat) ${WARN} Make sure to run 'qbt settings' to check configuration."
    fi
    }

function jqCheck() {
    if ! command -v jq > /dev/null 2>&1; then
        echo -e "$(dateFormat) ${ERROR} jq is not installed. Please install jq and run the script again."
        exit 1
    fi
    }

function checkLogStatus() {
        if [ ! -f "$qBitTorrentLog" ]; then
                echo -e "$(dateFormat) ${WARN} Cannot find $qBTlog. Check the path to your qBitTorrent Logs." | tee -a "$logFile"
                exit 1
        elif [ ! -r "$qBitTorrentLog" ]; then
                echo -e "$(dateFormat) ${WARN} Cannot read from $qBTlog. Check permissions." | tee -a "$logFile"
                exit 1
        elif [ ! -f "$logFile" ]; then
                touch $logFile
        elif [ ! -w "$logFile" ]; then
                echo -e "$(dateFormat) ${WARN} Cannot write to $logFile . Check permissions."
                exit 1
        fi
}

function buildArrays() {
        #Array lists releases not deleted properly
        qBTappLog=`cat $qBitTorrentLog | grep 'Error: "Directory not empty"' | awk '{ gsub(/"|\.$/,"",$13); print $13 }'`
        qBTappArray=($qBTappLog)
        #Array lists files already cleaned up
        qBTcleanLog=`cat $logFile | grep "\[FLCK\]" | awk '{ print $3 }' | sed -r 's:^'$torrentPath'/::' | sed "s/\/$//"`
        qBTcleanArray=($qBTcleanLog)
        #Test array
        qBTtestLog=`cat $logFile | grep "\[TEST\]" | awk '{ print $3 }' | sed -r 's:^'$torrentPath'/::' | sed "s/\/$//"`
        qBTtestArray=($qBTtestLog)
}

### CRON functions

function cronHelp(){
    echo -e "${TEAL}$Name${RESET} | ${YEL}Version:${RESET} $version | ${RED}Repo:${RESET} https://github.com/Jarsky/qBitTorrent-Cleanup-Script

    Usage $0 -cron [command]

    add                    Will add cron entry (Default every 4 hours)
    legacy                 Will add cron for legacy (Default every 4 hours)
    remove                 Will delete cron entry"
    echo -e ""
}

function confirmCronJob() {
    read -p "Are you sure you want to add/remove a CRON job for $cronuser? (Y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "$(dateFormat) ${ERROR} CRON Job creation/removal cancelled by user" | tee -a $logFile
        exit 1
    fi
}

function createCronJob(){
    checkLogStatus
    if [[ -z `crontab -l | grep "## qBitTorrent-Cleanup"` ]]; then
        (crontab -l 2>/dev/null; echo; echo "## qBitTorrent-Cleanup cron") | crontab -
    fi
    if [[ -z `crontab -l | grep "qBitTorrent-Cleanup.*$1"` ]]; then
        (crontab -l 2>/dev/null; echo "* 4 * * *      cd $current_dir && ./qBitTorrent-Cleanup.sh $2") | crontab -
        echo -e "$(dateFormat) ${INFO} CRON Job [$1] created for $cronuser" | tee -a $logFile
    else echo -e "$(dateFormat) ${INFO} CRON Job [$1] already exists for $cronuser" | tee -a $logFile
    fi
}

function removeCronJob(){
    checkLogStatus
    cronjobs=$(crontab -l | grep "qBitTorrent-Cleanup")
    if [[ -z $cronjobs ]]; then
        echo -e "$(dateFormat) ${ERROR} CRON No qBitTorrent-Cleanup jobs found for $cronuser" | tee -a $logFile
    else
        crontab -l | grep -v "qBitTorrent-Cleanup" | crontab -
        echo -e "$(dateFormat) ${INFO} CRON qBitTorrent-Cleanup jobs have been removed from $cronuser" | tee -a $logFile
    fi
}


#Script

if [ $dependencyCheck = "true" ]; then
    checkOS
    checkDependencies
fi

if [[ $# -eq 0 ]]; then
        echo -e "$(dateFormat) ${WARN} No command was defined."
        echo -e "$(dateFormat) ${INFO} You need to enter a command. for a list use $0 --help"
        exit 1
fi

if [[ $1 == "-h" || $1 == "--help" ]]; then
        helpCMD
    elif [[ $1 == "-v" || $1 == "--version" ]]; then
        versionCMD

    elif [[ $1 == "cron" ||$1 == "-cron" ]]; then
        current_dir=$(pwd)
        cronuser=${teal}$(whoami)${RESET}
        argError="$(dateFormat) ${ERROR} ${red}Invalid Argument '$2' ${RESET}: Check your syntax. Use --help for a list"
        if [[ $# -eq 1 ]]; then
            cronHelp
        elif [[ $2 != "add" ]] && [[ $2 != "legacy" ]] && [[ $2 != "remove" ]]; then
            echo -e $argError
            exit 1
        fi
        if [[ $2 == "add" ]]; then
            confirmCronJob
            createCronJob "run" "-run"
        elif [[ $2 == "legacy" ]]; then
            confirmCronJob
            createCronJob "legacy" "-legacy"
        elif [[ $2 == "remove" ]]; then
            confirmCronJob
            removeCronJob
        fi

elif [[ $1 == "-legacy" ]]; then

        # Initialize
        checkLogStatus
        buildArrays

        for qbitLogName in "${qBTappArray[@]}";
        do
                if [[ $2 == "test" || $2 == "-test" ]]; then
                        if [[ ! " ${qBTtestArray[*]} " =~ " ${qBTcleanArray[*]} " ]]; then
                                if [ -d "$torrentPath/$qbitLogName" ]; then
                                        if ! grep -q -E "\\[TEST\\].*$torrentName.*$" $logFile; then
                                                echo -e "$(dateFormat) ${TEST} $qbitLogName exists but is INFO only mode"  | tee -a "$logFile"
                                        else
                                                echo -e "$(dateFormat) ${TEST} $qbitLogName doesnt exist in: $torrentPath"  | tee -a "$logFile"
                                        fi
                                else
                                        echo -e "$(dateFormat) ${TEST} $torrentPath/$qbitLogName has already been deleted"
                        fi
                elif ! grep -q -E "\\[FLCK\\].*$torrentName.*$" $logFile; then
                                echo -e "$(dateFormat) [FLCK] $torrentPath/$qbitLogName/ doesnt exist."  | tee -a "$logFile"
                        else
                                echo -e "$(dateFormat) ${INFO} $torrentPath/$qbitLogName/ already exists in the log"
                        fi
                else
                        if [ -d "$torrentPath/$qbitLogName" ]; then
                                echo -e "$(dateFormat) ${INFO} $torrentPath/$qbitLogName/ will be deleted"  | tee -a "$logFile"
                                deleted=`strace rm -r $torrentPath/$qbitLogName/ |& grep "+++ exited with" | awk '{print $4}'` #Exit Code: 0=OK 1=Error
                                        if [ $deleted -eq "0" ]; then
                                                echo -e "$(dateFormat) ${INFO} $qbitLogName deleted successfully."  | tee -a "$logFile"
                                        elif [ $deleted -eq "1" ]; then
                                                echo -e "$(dateFormat) ${WARN} $qbitLogName not deleted. Possibly file locked."  | tee -a "$logFile"
                                        else
                                                echo -e "$(dateFormat) ${ERROR} $qbitLogName had an unexpected error."  | tee -a "$logFile"
                                        fi
                        else
                                echo -e "$(dateFormat) ${INFO} $torrentPath/$qbitLogName has already been deleted."
                        fi
                fi
        done


elif [[ $1 == "run" ||$1 == "-run" ]]; then

    
        # Initialize
        checkLogStatus
        buildArrays

        qbt torrent list -F json > $jsonFilename
        mapfile -t torrentNames < <(jq -r '.[].name' $jsonFilename)

        echo -e "$(dateFormat) ${ERROR} This hasnt been finished, use legacy mode"
        echo -e "$(dateFormat) ${ERROR} Use $0 --help for more commands"

fi




