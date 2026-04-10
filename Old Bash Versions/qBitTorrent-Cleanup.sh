#!/bin/bash
####################################################################################################
#
#       qBitTorrent-Cleanup by Jarsky
#       Refactored & fixed by Claude
#
#       Updated:  2026
#       Version:  v2.0
#
#       Summary:
#           Checks the qBittorrent log for torrents that were removed but whose
#           files/folders were not cleaned up, then deletes those leftovers.
#
#           -legacy mode:  parses the qBittorrent application log directly
#           -run mode:     uses qbittorrent-cli + API (requires qbt CLI configured)
#
#       Pre-requisites:
#           -run mode only: install qbittorrent-cli
#               https://github.com/fedarovich/qbittorrent-cli
#           Install jq:  apt install -y jq
#
#       Usage:
#           ./qBitTorrent-Cleanup.sh --help
#
#       Repo: https://github.com/Jarsky/qBitTorrent-Cleanup-Script
#
####################################################################################################

# ── Configuration ─────────────────────────────────────────────────────────────
torrentPath=/mnt/share/INCOMING/complete
qBitTorrentLog=/opt/appdata/qbittorrent/config/qBittorrent/logs/qbittorrent.log
logFile=/var/log/qBitTorrent-Cleanup.log
jsonFilename=/tmp/qbt_torrent_list.json
qbtcliSettings=~/.qbt/settings.json
dependencyCheck="true"

###### No edits needed below this line ###########################################

Name="qBitTorrent-Cleanup"
version="2.0"

# ── Colours (tput - PuTTY safe, degrades if unsupported) ──────────────────────
if [[ -t 1 ]] && command -v tput &>/dev/null && tput colors &>/dev/null && (( $(tput colors) >= 8 )); then
    RED=$(tput setaf 1)
    GRN=$(tput setaf 2)
    YEL=$(tput setaf 3)
    TEAL=$(tput setaf 6)
    MAGENTA=$(tput setaf 5)
    WHITE=$(tput setaf 7)
    BOLD=$(tput bold)
    RESET=$(tput sgr0)
else
    RED=''; GRN=''; YEL=''; TEAL=''; MAGENTA=''; WHITE=''; BOLD=''; RESET=''
fi

# Plain versions for log file (no colour codes)
_plain() { sed 's/\x1b\[[0-9;]*m//g; s/\x1b(B//g'; }

# Log-level tags  (colour on screen, plain in file)
TAG_ERROR="[ERROR]"
TAG_WARN="[WARN]"
TAG_INFO="[INFO]"
TAG_TEST="[TEST]"
TAG_FLCK="[FLCK]"

# ── Logging ───────────────────────────────────────────────────────────────────
# Usage: log_msg LEVEL "message"
# LEVEL is one of: ERROR WARN INFO TEST FLCK
log_msg() {
    local level="$1"; shift
    local msg="$*"
    local ts
    ts=$(date +"[%Y-%m-%d %H:%M:%S]")

    local colour tag
    case "$level" in
        ERROR) colour="$RED";     tag="$TAG_ERROR" ;;
        WARN)  colour="$YEL";     tag="$TAG_WARN"  ;;
        INFO)  colour="$TEAL";    tag="$TAG_INFO"  ;;
        TEST)  colour="$MAGENTA"; tag="$TAG_TEST"  ;;
        FLCK)  colour="$GRN";     tag="$TAG_FLCK"  ;;
        *)     colour="";         tag="[$level]"   ;;
    esac

    # Screen: coloured tag
    printf '%s %b%s%b %s\n' "$ts" "$colour" "$tag" "$RESET" "$msg"

    # Log file: plain text, only write levels that should be persisted
    case "$level" in
        ERROR|WARN|INFO|FLCK)
            printf '%s %s %s\n' "$ts" "$tag" "$msg" >> "$logFile"
            ;;
    esac
}

# ── OS Detection ──────────────────────────────────────────────────────────────
checkOS() {
    if [[ -f /etc/lsb-release ]]; then
        . /etc/lsb-release
        OS=$DISTRIB_ID
        VER=$DISTRIB_RELEASE
    elif [[ -f /etc/debian_version ]]; then
        OS=Debian
        VER=$(cat /etc/debian_version)
    elif [[ -f /etc/redhat-release ]]; then
        OS=CentOS
        VER=$(rpm -qa \*-release | grep -Ei "oracle|redhat|centos" | cut -d"-" -f3)
    else
        OS=$(uname -s)
        VER=$(uname -r)
    fi
}

# ── Dependency Check ──────────────────────────────────────────────────────────
checkDependencies() {
    local missing=false

    if [[ "$OS" == "Ubuntu" || "$OS" == "Debian" ]]; then
        if ! dpkg-query -W -f='${Status}' moreutils 2>/dev/null | grep -q "ok installed"; then
            missing=true
            if [[ "$EUID" -ne 0 ]]; then
                printf '%b\n' "${YEL}moreutils is not installed and is required.${RESET}"
                printf '%b\n' "${YEL}Re-run as root or sudo to install it automatically.${RESET}"
                exit 1
            fi
            apt-get -y install moreutils
        fi
    elif [[ "$OS" == "CentOS" ]]; then
        if ! rpm -q moreutils &>/dev/null; then
            missing=true
            if [[ "$EUID" -ne 0 ]]; then
                printf '%b\n' "${YEL}moreutils is not installed and is required.${RESET}"
                printf '%b\n' "${YEL}Re-run as root or sudo to install it automatically.${RESET}"
                exit 1
            fi
            yum -y install moreutils
        fi
    fi

    if [[ "$missing" == true ]]; then
        printf '%b\n' "${GRN}Dependencies installed. You can now run the script normally.${RESET}"
        exit 0
    fi
}

checkJq() {
    if ! command -v jq &>/dev/null; then
        log_msg ERROR "jq is not installed. Run: apt install -y jq"
        exit 1
    fi
}

checkQbtCli() {
    if [[ ! -f "$qbtcliSettings" ]]; then
        log_msg WARN "qbt CLI settings not found at $qbtcliSettings"
        log_msg WARN "Run 'qbt settings' to configure it before using -run mode."
        exit 1
    fi
}

# ── Log File / qBT Log Checks ─────────────────────────────────────────────────
checkLogStatus() {
    if [[ ! -f "$qBitTorrentLog" ]]; then
        log_msg WARN "Cannot find qBittorrent log: $qBitTorrentLog"
        exit 1
    fi
    if [[ ! -r "$qBitTorrentLog" ]]; then
        log_msg WARN "Cannot read qBittorrent log: $qBitTorrentLog  (check permissions)"
        exit 1
    fi
    if [[ ! -f "$logFile" ]]; then
        touch "$logFile" || { log_msg ERROR "Cannot create log file: $logFile"; exit 1; }
    fi
    if [[ ! -w "$logFile" ]]; then
        log_msg ERROR "Cannot write to log file: $logFile  (check permissions)"
        exit 1
    fi
}

# ── Build Working Arrays ───────────────────────────────────────────────────────
# qBTappArray  = torrent names qBT failed to delete (from qBT app log)
# qBTcleanArray = torrent names this script already processed (from our log)
declare -a qBTappArray=()
declare -a qBTcleanArray=()

buildArrays() {
    # Torrents qBT tried to remove but couldn't clean up
    mapfile -t qBTappArray < <(
        grep 'Removed torrent but failed to delete its content and/or partfile' "$qBitTorrentLog" \
        | awk -F 'Torrent: "|"' '{print $2}' \
        | sort -u
    )

    # Entries this script already handled (avoid reprocessing)
    mapfile -t qBTcleanArray < <(
        grep "\[FLCK\]" "$logFile" \
        | awk '{print $3}' \
        | sed -E "s|^${torrentPath}/||; s|/$||" \
        | sort -u
    )
}

# Returns 0 (true) if the torrent name has already been processed
alreadyProcessed() {
    local name="$1"
    local entry
    for entry in "${qBTcleanArray[@]}"; do
        [[ "$entry" == "$name" ]] && return 0
    done
    return 1
}

# ── Delete a Leftover Directory ───────────────────────────────────────────────
deleteDirectory() {
    local name="$1"
    local fullPath="${torrentPath}/${name}"

    log_msg INFO "Deleting: $fullPath"

    if rm -rf "$fullPath"; then
        # Verify it's actually gone
        if [[ ! -e "$fullPath" ]]; then
            log_msg FLCK "$fullPath"
            log_msg INFO "$name deleted successfully."
        else
            log_msg WARN "$name: rm reported success but path still exists."
        fi
    else
        log_msg WARN "$name: deletion failed — file may be locked or permissions issue."
    fi
}

# ── Help / Version ────────────────────────────────────────────────────────────
helpCMD() {
    printf '%b\n' "
${TEAL}${BOLD}${Name}${RESET} | ${YEL}Version:${RESET} ${version} | Repo: https://github.com/Jarsky/qBitTorrent-Cleanup-Script

  ${BOLD}Usage:${RESET} $0 [command] [option]

  ${BOLD}Commands:${RESET}

    -legacy            Parse qBittorrent app log and delete leftover folders
    -legacy test       Same but read-only preview (no deletions)

    -run               Use qbittorrent-cli + API mode  (requires qbt CLI)
    -run test          Read-only preview via qbt CLI

    -cron              Show cron management options

    -h | --help        Show this help
    -v | --version     Show version info
"
}

versionCMD() {
    printf '%b\n' "
${TEAL}${BOLD}${Name}${RESET} | ${YEL}Version:${RESET} ${version}

  ${MAGENTA}Author:${RESET}       Jarsky
  ${MAGENTA}Refactor:${RESET}     v2.0 - Fixed dedup logic, removed strace dependency,
                  tput colours, printf throughout, finished -run mode
  ${MAGENTA}v1.6:${RESET}         Fixed logic in legacy mode
  ${MAGENTA}v1.5:${RESET}         Moved original logic to legacy, added qbt-CLI mode
  ${MAGENTA}v1.4:${RESET}         Refactored and added functions
"
}

# ── CRON Helpers ──────────────────────────────────────────────────────────────
cronHelp() {
    printf '%b\n' "
${TEAL}${BOLD}${Name}${RESET} | Cron Management

  ${BOLD}Usage:${RESET} $0 -cron [command]

    add       Add cron entry for -run mode     (runs daily at 04:00)
    legacy    Add cron entry for -legacy mode  (runs daily at 04:00)
    remove    Remove all qBitTorrent-Cleanup cron entries
"
}

confirmCronAction() {
    local cronuser
    cronuser=$(whoami)
    printf '%b' "${YEL}Are you sure you want to modify the crontab for ${BOLD}${cronuser}${RESET}${YEL}? [y/N] ${RESET}"
    read -r reply
    if [[ ! "$reply" =~ ^[Yy]$ ]]; then
        log_msg ERROR "Cron action cancelled by user."
        exit 1
    fi
}

createCronJob() {
    local label="$1"
    local flag="$2"
    local current_dir
    current_dir=$(pwd)

    # Add comment header if not present
    if ! crontab -l 2>/dev/null | grep -q "## qBitTorrent-Cleanup"; then
        (crontab -l 2>/dev/null; echo ""; echo "## qBitTorrent-Cleanup cron") | crontab -
    fi

    # Add the job if not already present  (note: 0 4 = 04:00, not * 4 which is every minute of 4am hour)
    if crontab -l 2>/dev/null | grep -q "qBitTorrent-Cleanup.*${flag}"; then
        log_msg INFO "Cron job [${label}] already exists for $(whoami)"
    else
        (crontab -l 2>/dev/null; echo "0 4 * * *    cd ${current_dir} && ./qBitTorrent-Cleanup.sh ${flag}") | crontab -
        log_msg INFO "Cron job [${label}] created for $(whoami) — runs daily at 04:00"
    fi
}

removeCronJob() {
    if ! crontab -l 2>/dev/null | grep -q "qBitTorrent-Cleanup"; then
        log_msg ERROR "No qBitTorrent-Cleanup cron jobs found for $(whoami)"
    else
        crontab -l | grep -v "qBitTorrent-Cleanup" | crontab -
        log_msg INFO "All qBitTorrent-Cleanup cron jobs removed for $(whoami)"
    fi
}

# =============================================================================
#  LEGACY MODE
#  Reads the qBittorrent app log, finds torrents whose folders weren't cleaned,
#  and deletes them. Skips any already recorded in our own log file.
# =============================================================================
runLegacy() {
    local testMode=false
    [[ "${2:-}" == "test" || "${2:-}" == "-test" ]] && testMode=true

    checkLogStatus
    buildArrays

    if (( ${#qBTappArray[@]} == 0 )); then
        log_msg INFO "No failed-deletion entries found in qBittorrent log. Nothing to do."
        exit 0
    fi

    log_msg INFO "Found ${#qBTappArray[@]} torrent(s) in qBittorrent log that failed cleanup."
    $testMode && log_msg TEST "Running in TEST mode — no files will be deleted."

    local processed=0 skipped=0 missing=0

    for name in "${qBTappArray[@]}"; do
        local fullPath="${torrentPath}/${name}"

        if $testMode; then
            if [[ -d "$fullPath" ]]; then
                log_msg TEST "$name — directory exists, would be deleted"
            else
                log_msg TEST "$name — directory not found (already cleaned up)"
            fi
            continue
        fi

        # Skip if we already handled this one
        if alreadyProcessed "$name"; then
            log_msg INFO "$name — already processed, skipping."
            (( skipped++ )) || true
            continue
        fi

        if [[ -d "$fullPath" ]]; then
            deleteDirectory "$name"
            (( processed++ )) || true
        else
            log_msg INFO "$fullPath — directory not found, already cleaned up."
            (( missing++ )) || true
        fi
    done

    if ! $testMode; then
        log_msg INFO "Done. Deleted: ${processed} | Already gone: ${missing} | Skipped (logged): ${skipped}"
    fi
}

# =============================================================================
#  RUN MODE (qbt CLI)
#  Compares the active torrent list from the API against what's on disk.
#  Anything in the torrent path that is NOT in the active list gets deleted.
# =============================================================================
runQbtCli() {
    local testMode=false
    [[ "${2:-}" == "test" || "${2:-}" == "-test" ]] && testMode=true

    checkLogStatus
    checkJq
    checkQbtCli

    log_msg INFO "Fetching torrent list via qbt CLI..."
    if ! qbt torrent list -F json > "$jsonFilename" 2>/dev/null; then
        log_msg ERROR "Failed to fetch torrent list. Check qbt CLI is configured and qBittorrent is running."
        exit 1
    fi

    # Build a lookup of active torrent names
    mapfile -t activeTorrents < <(jq -r '.[].name' "$jsonFilename")

    if (( ${#activeTorrents[@]} == 0 )); then
        log_msg WARN "No active torrents returned by qbt CLI. Aborting to avoid mass deletion."
        exit 1
    fi

    log_msg INFO "Active torrents in qBittorrent: ${#activeTorrents[@]}"
    $testMode && log_msg TEST "Running in TEST mode — no files will be deleted."

    # Build a fast lookup set
    declare -A activeSet
    for t in "${activeTorrents[@]}"; do
        activeSet["$t"]=1
    done

    local processed=0 skipped=0

    # Walk everything in torrentPath; delete if not in active list
    for entry in "$torrentPath"/*/; do
        [[ -d "$entry" ]] || continue
        local name
        name=$(basename "$entry")

        if [[ -n "${activeSet[$name]+_}" ]]; then
            # Still active in qBittorrent — leave it alone
            continue
        fi

        if alreadyProcessed "$name"; then
            log_msg INFO "$name — already processed, skipping."
            (( skipped++ )) || true
            continue
        fi

        if $testMode; then
            log_msg TEST "$name — not in active torrent list, would be deleted"
        else
            deleteDirectory "$name"
            (( processed++ )) || true
        fi
    done

    if ! $testMode; then
        log_msg INFO "Done. Deleted: ${processed} | Skipped (logged): ${skipped}"
    fi

    rm -f "$jsonFilename"
}

# =============================================================================
#  Entry point
# =============================================================================
if [[ "$dependencyCheck" == "true" ]]; then
    checkOS
    checkDependencies
fi

if [[ $# -eq 0 ]]; then
    log_msg WARN "No command specified. Run $0 --help for usage."
    exit 1
fi

case "$1" in
    -h|--help)    helpCMD ;;
    -v|--version) versionCMD ;;

    -cron|cron)
        if [[ $# -eq 1 ]]; then
            cronHelp
        else
            case "$2" in
                add)    confirmCronAction; checkLogStatus; createCronJob "run"    "-run"    ;;
                legacy) confirmCronAction; checkLogStatus; createCronJob "legacy" "-legacy" ;;
                remove) confirmCronAction; checkLogStatus; removeCronJob           ;;
                *)
                    log_msg ERROR "Unknown cron argument: $2  (use add, legacy, or remove)"
                    exit 1
                    ;;
            esac
        fi
        ;;

    -legacy|legacy) runLegacy "$@" ;;
    -run|run)       runQbtCli "$@" ;;

    *)
        log_msg ERROR "Unknown command: $1"
        helpCMD
        exit 1
        ;;
esac
