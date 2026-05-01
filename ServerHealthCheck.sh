#!/bin/bash
# Server Health Check - fixed version of BadServerHealthCheck.sh
# Removed: duplicate loop, dead vars, temp files, broken float compare, redundant df, slang
set -euo pipefail  # stop on errors instead of ignoring them

LOGFILE="/var/log/server_health_$(date +%Y%m%d_%H%M%S).log"  # timestamped filename
CPU_WARN=80; MEM_WARN=85; DISK_WARN=90  # thresholds for warnings

log() { echo "$1" | tee -a "$LOGFILE"; }  # print to screen + log

log "===== Health Check - $(hostname) - $(date) ====="

# CPU: grab idle% from top batch mode, subtract from 100
log "-- CPU --"
idle=$(top -bn1 | grep "Cpu(s)" | awk '{print $8}' | tr -d '%,')
cpu=$(awk "BEGIN {printf \"%.1f\", 100 - $idle}")
log "Usage: ${cpu}%"
(( $(printf "%.0f" "$cpu") > CPU_WARN )) && log "WARNING: above ${CPU_WARN}%!" || log "OK"

# Memory: free -m for megabytes, compute percentage with awk (not bash, bash cant do floats)
log "-- Memory --"
read -r used total <<< "$(free -m | awk '/^Mem:/{print $3,$2}')"
pct=$(awk "BEGIN {printf \"%.1f\", ($used/$total)*100}")
log "RAM: ${used}MB / ${total}MB (${pct}%)"
(( $(printf "%.0f" "$pct") > MEM_WARN )) && log "WARNING: above ${MEM_WARN}%!" || log "OK"

# Disk: single df call, exclude virtual filesystems, loop real ones
log "-- Disk --"
df -h -x tmpfs -x devtmpfs -x squashfs | awk 'NR>1{print $1,$6,$5}' | while read -r dev mnt use; do
    log "  $dev on $mnt - ${use} used"
    (( ${use%\%} > DISK_WARN )) && log "  WARNING: $mnt over ${DISK_WARN}%!"
done

# Network: ping default gateway, not google (works behind firewalls)
log "-- Network --"
gw=$(ip route | awk '/default/{print $3; exit}')
if [ -z "$gw" ]; then
    log "WARNING: no default gateway"
elif ping -c1 -W3 "$gw" &>/dev/null; then
    log "Gateway $gw reachable - OK"
else
    log "WARNING: cant reach gateway $gw"
fi

log "Done. Report: $LOGFILE"
