#!/bin/bash

###############################################################################
# Server Diagnostic & Troubleshooting Script
# 
# Purpose: Diagnoses common server issues including network misconfiguration,
#          boot/filesystem corruption, permission problems, and disk space issues.
#
# Usage:   Run as root:  sudo bash server_diag.sh
# Output:  Creates a report file at /tmp/server_diagnostic_report.txt
#
# Requirements: Must be run as root. No additional packages needed.
#
# Author:  Darwin M.
# Date:    April 22,2026
# GitHub:  https://github.com/Darewiin/LinuxScripts
###############################################################################

# --- Configuration ---
REPORT="/tmp/server_diagnostic_report.txt"
TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")
HOSTNAME=$(hostname 2>/dev/null || echo "unknown")
ISSUES_FOUND=0

# --- Check for root ---
if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: This script must be run as root."
    echo "Usage: sudo bash $0"
    exit 1
fi

# --- Helper Functions ---
log() {
    echo "$1" | tee -a "$REPORT"
}

section() {
    log ""
    log "========================================"
    log "  $1"
    log "========================================"
}

pass() {
    log "  [PASS] $1"
}

warn() {
    log "  [WARN] $1"
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
}

fail() {
    log "  [FAIL] $1"
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
}

info() {
    log "  [INFO] $1"
}

# --- Start Report ---
> "$REPORT"
log "========================================"
log "  SERVER DIAGNOSTIC REPORT"
log "  Host: $HOSTNAME"
log "  Date: $TIMESTAMP"
log "  OS:   $(cat /etc/os-release 2>/dev/null | grep PRETTY_NAME | cut -d= -f2 | tr -d '"')"
log "========================================"

###############################################################################
# CHECK 1: NETWORK CONFIGURATION
###############################################################################
section "NETWORK CONFIGURATION"

# Check DNS resolution
if [ -f /etc/resolv.conf ]; then
    DNS_SERVERS=$(grep "^nameserver" /etc/resolv.conf | awk '{print $2}')
    for dns in $DNS_SERVERS; do
        # Check for obviously invalid DNS IPs
        if echo "$dns" | grep -qE "^999\.|\.999"; then
            fail "Invalid DNS server found: $dns"
        else
            info "DNS server configured: $dns"
        fi
    done
    
    # Check if resolv.conf is read-only
    if [ ! -w /etc/resolv.conf ]; then
        warn "/etc/resolv.conf is read-only (permissions: $(stat -c %a /etc/resolv.conf))"
    fi
else
    fail "/etc/resolv.conf does not exist"
fi

# Check for broken netplan configs
if [ -d /etc/netplan ]; then
    info "Netplan configuration directory found"
    for f in /etc/netplan/*.yaml /etc/netplan/*.yml; do
        [ -f "$f" ] || continue
        info "Checking netplan file: $f"
        if grep -qE "192\.168\.[0-9]+\.([3-9][0-9]{2}|[0-9]{4,})" "$f" 2>/dev/null; then
            fail "Invalid IP address found in $f"
        fi
        if grep -q "999\.999\.999\.999" "$f" 2>/dev/null; then
            fail "Invalid DNS server in $f"
        fi
    done
fi

# Check for broken /etc/network/interfaces
if [ -f /etc/network/interfaces ]; then
    info "Checking /etc/network/interfaces"
    if grep -q "sttic" /etc/network/interfaces; then
        fail "Typo in /etc/network/interfaces: 'sttic' instead of 'static'"
    fi
    if grep -qE "192\.168\.[0-9]+\.([3-9][0-9]{2}|[0-9]{4,})" /etc/network/interfaces; then
        fail "Invalid IP address in /etc/network/interfaces"
    fi
    if grep -qE "255\.255\.255\.([3-9][0-9]{2}|[0-9]{4,})" /etc/network/interfaces; then
        fail "Invalid netmask in /etc/network/interfaces"
    fi
fi

# Check default route
if ! ip route show default 2>/dev/null | grep -q "default"; then
    fail "No default route configured"
else
    DEFAULT_GW=$(ip route show default | awk '{print $3}')
    info "Default gateway: $DEFAULT_GW"
    if echo "$DEFAULT_GW" | grep -qE "\.999$|\.500$"; then
        fail "Invalid default gateway: $DEFAULT_GW"
    fi
fi

# Test connectivity
if ping -c 1 -W 3 8.8.8.8 > /dev/null 2>&1; then
    pass "Network connectivity to 8.8.8.8 works"
else
    warn "Cannot reach 8.8.8.8 - network may be down"
fi

if ping -c 1 -W 3 google.com > /dev/null 2>&1; then
    pass "DNS resolution works"
else
    warn "Cannot resolve google.com - DNS may be broken"
fi

###############################################################################
# CHECK 2: BOOT & FILESYSTEM CONFIGURATION
###############################################################################
section "BOOT & FILESYSTEM CONFIGURATION"

# Check GRUB config
GRUB_CFG=""
if [ -f /boot/grub/grub.cfg ]; then
    GRUB_CFG="/boot/grub/grub.cfg"
elif [ -f /boot/grub2/grub.cfg ]; then
    GRUB_CFG="/boot/grub2/grub.cfg"
fi

if [ -n "$GRUB_CFG" ]; then
    info "GRUB config found: $GRUB_CFG"
    if grep -q "vmlinux" "$GRUB_CFG" && ! grep -q "vmlinuz" "$GRUB_CFG"; then
        fail "GRUB references 'vmlinux' instead of 'vmlinuz' - kernel will not be found on boot"
    fi
    if grep -q "root=UUID=broken-" "$GRUB_CFG"; then
        fail "GRUB has corrupted root UUID (contains 'broken-' prefix)"
    fi
else
    info "No GRUB config found (may use different bootloader)"
fi

# Check /etc/fstab
if [ -f /etc/fstab ]; then
    info "Checking /etc/fstab"
    if grep -q "/dev/sda99" /etc/fstab; then
        fail "Fake device /dev/sda99 found in /etc/fstab - will fail on boot"
    fi
    if grep -q "errors=panic" /etc/fstab; then
        fail "fstab has errors=panic - system will kernel panic on filesystem errors"
    fi
    # Check for non-existent mount points
    while IFS= read -r line; do
        # Skip comments and empty lines
        echo "$line" | grep -q "^#" && continue
        echo "$line" | grep -q "^$" && continue
        DEV=$(echo "$line" | awk '{print $1}')
        MOUNT=$(echo "$line" | awk '{print $2}')
        if echo "$DEV" | grep -q "^/dev/"; then
            if [ ! -b "$DEV" ] && ! echo "$DEV" | grep -q "mapper"; then
                warn "Device $DEV in fstab may not exist"
            fi
        fi
    done < /etc/fstab
fi

# Check for forcefsck flag
if [ -f /forcefsck ]; then
    warn "/forcefsck file exists - filesystem check will be forced on next boot"
fi

###############################################################################
# CHECK 3: FILE PERMISSIONS
###############################################################################
section "FILE PERMISSIONS"

# Check critical binary permissions
for bin in /bin/ls /bin/cat /usr/bin/ls /usr/bin/cat; do
    if [ -f "$bin" ]; then
        PERMS=$(stat -c %a "$bin")
        if [ "$PERMS" = "644" ] || [ "$PERMS" = "600" ]; then
            fail "$bin is not executable (permissions: $PERMS, should be 755)"
        else
            pass "$bin permissions OK ($PERMS)"
        fi
    fi
done

# Check /etc/passwd permissions
if [ -f /etc/passwd ]; then
    PERMS=$(stat -c %a /etc/passwd)
    if [ "$PERMS" = "600" ]; then
        fail "/etc/passwd is too restrictive ($PERMS) - should be 644"
    elif [ "$PERMS" = "644" ]; then
        pass "/etc/passwd permissions OK ($PERMS)"
    else
        warn "/etc/passwd has unusual permissions ($PERMS)"
    fi
fi

# Check /etc/shadow ownership
if [ -f /etc/shadow ]; then
    OWNER=$(stat -c %U /etc/shadow)
    if [ "$OWNER" = "nobody" ]; then
        fail "/etc/shadow owned by 'nobody' - should be root"
    elif [ "$OWNER" = "root" ]; then
        pass "/etc/shadow ownership OK (root)"
    else
        warn "/etc/shadow owned by '$OWNER' - expected root"
    fi
fi

# Check /etc/sudoers
if [ -f /etc/sudoers ]; then
    PERMS=$(stat -c %a /etc/sudoers)
    OWNER=$(stat -c %U:%G /etc/sudoers)
    if [ "$PERMS" = "777" ]; then
        fail "/etc/sudoers is world-writable ($PERMS) - sudo will refuse to work"
    elif [ "$PERMS" = "440" ] || [ "$PERMS" = "400" ]; then
        pass "/etc/sudoers permissions OK ($PERMS)"
    else
        warn "/etc/sudoers has unusual permissions ($PERMS)"
    fi
    if [ "$OWNER" != "root:root" ]; then
        fail "/etc/sudoers ownership is $OWNER - should be root:root"
    fi
fi

# Check SSH config permissions
if [ -f /etc/ssh/sshd_config ]; then
    PERMS=$(stat -c %a /etc/ssh/sshd_config)
    if [ "$PERMS" = "777" ]; then
        fail "/etc/ssh/sshd_config is world-writable ($PERMS) - SSH will refuse to start"
    elif [ "$PERMS" = "644" ] || [ "$PERMS" = "600" ]; then
        pass "/etc/ssh/sshd_config permissions OK ($PERMS)"
    else
        warn "/etc/ssh/sshd_config has unusual permissions ($PERMS)"
    fi
fi

###############################################################################
# CHECK 4: DISK SPACE
###############################################################################
section "DISK SPACE"

# Check overall disk usage
DISK_USAGE=$(df / | tail -1 | awk '{print $5}' | tr -d '%')
if [ "$DISK_USAGE" -gt 90 ]; then
    fail "Root filesystem is $DISK_USAGE% full"
elif [ "$DISK_USAGE" -gt 75 ]; then
    warn "Root filesystem is $DISK_USAGE% full"
else
    pass "Root filesystem usage OK ($DISK_USAGE%)"
fi

# Check for suspiciously large files
for suspect in /var/log/bigfile /tmp/hugefile; do
    if [ -f "$suspect" ]; then
        SIZE=$(du -sh "$suspect" 2>/dev/null | awk '{print $1}')
        fail "Suspicious large file found: $suspect ($SIZE)"
    fi
done

# Check for large files in /var/log and /tmp
LARGE_FILES=$(find /var/log /tmp -type f -size +100M 2>/dev/null)
if [ -n "$LARGE_FILES" ]; then
    warn "Large files (>100MB) found:"
    echo "$LARGE_FILES" | while read -r f; do
        SIZE=$(du -sh "$f" 2>/dev/null | awk '{print $1}')
        info "  $f ($SIZE)"
    done
fi

# Check logrotate config
if [ -f /etc/logrotate.conf ]; then
    LINE_COUNT=$(wc -l < /etc/logrotate.conf)
    if [ "$LINE_COUNT" -le 2 ]; then
        CONTENT=$(cat /etc/logrotate.conf)
        if echo "$CONTENT" | grep -q "invalid"; then
            fail "/etc/logrotate.conf has been corrupted (contains 'invalid content')"
        fi
    else
        pass "/etc/logrotate.conf appears intact"
    fi
fi

###############################################################################
# CHECK 5: SERVICES STATUS
###############################################################################
section "SERVICES STATUS"

# Check for failed services
FAILED=$(systemctl list-units --state=failed --no-legend 2>/dev/null)
if [ -n "$FAILED" ]; then
    warn "Failed services detected:"
    echo "$FAILED" | while read -r line; do
        info "  $line"
    done
else
    pass "No failed services"
fi

# Check SSH service
if systemctl is-active --quiet sshd 2>/dev/null; then
    pass "SSH service (sshd) is running"
elif systemctl is-active --quiet ssh 2>/dev/null; then
    pass "SSH service (ssh) is running"
else
    warn "SSH service is not running"
fi

###############################################################################
# SUMMARY
###############################################################################
section "SUMMARY"
log ""
if [ "$ISSUES_FOUND" -gt 0 ]; then
    log "  Total issues found: $ISSUES_FOUND"
    log "  Review the [FAIL] and [WARN] items above."
else
    log "  No issues found. System appears healthy."
fi
log ""
log "  Report saved to: $REPORT"
log "========================================"

echo ""
echo "Diagnostic complete. Found $ISSUES_FOUND issue(s)."
echo "Full report: $REPORT"
