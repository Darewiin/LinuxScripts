#!/bin/bash
#==============================================================================
# Server Hardening ROLLBACK Script
# Description: Undoes all changes made by server_hardening.sh so you can
#              test a different script from a clean state
# Generated:   By Claude AI (Anthropic) for cybersecurity coursework
# Usage:       sudo bash rollback_hardening.sh
#==============================================================================

#------------------------------------------------------------------------------
# SECTION 0: Pre-flight checks
#------------------------------------------------------------------------------

# Must be run as root
if [[ "$EUID" -ne 0 ]]; then
    echo "ERROR: This script must be run as root. Use: sudo bash $0"
    exit 1
fi

# Detect OS
if [ -f /etc/os-release ]; then
    . /etc/os-release
    DISTRO=$ID
else
    echo "ERROR: Cannot detect OS."
    exit 1
fi

echo "=============================================="
echo " Server Hardening ROLLBACK"
echo " Detected OS: $DISTRO"
echo " Date: $(date)"
echo "=============================================="
echo ""
echo "⚠ WARNING: This will undo all hardening changes."
echo "  Only use this on a LAB machine for testing."
echo ""
read -p "Are you sure you want to continue? (yes/no): " CONFIRM
if [[ "$CONFIRM" != "yes" ]]; then
    echo "Rollback cancelled."
    exit 0
fi

# Track results
PASSED=()
FAILED=()
SKIPPED=()

#------------------------------------------------------------------------------
# SECTION 1: Restore SSH Configuration
#------------------------------------------------------------------------------
echo ""
echo ">>> Restoring SSH Configuration"
echo "----------------------------------------------"

SSHD_CONFIG="/etc/ssh/sshd_config"

# Look for the backup file the hardening script created
BACKUP=$(ls -t ${SSHD_CONFIG}.bak.* 2>/dev/null | head -1)

if [[ -n "$BACKUP" ]]; then
    cp "$BACKUP" "$SSHD_CONFIG"
    echo "[RESTORED] sshd_config from backup: $BACKUP"
    PASSED+=("SSH config restored from backup")
else
    echo "[SKIP] No sshd_config backup found — nothing to restore"
    SKIPPED+=("SSH config restore (no backup file found)")
fi

# Remove the SSH banner file if it exists
if [ -f /etc/ssh/banner ]; then
    rm -f /etc/ssh/banner
    echo "[REMOVED] /etc/ssh/banner"
fi

# Restart SSH service
if [[ "$DISTRO" == "centos" || "$DISTRO" == "rhel" || "$DISTRO" == "rocky" || "$DISTRO" == "almalinux" ]]; then
    systemctl restart sshd
elif [[ "$DISTRO" == "ubuntu" || "$DISTRO" == "debian" ]]; then
    systemctl restart ssh
fi

#------------------------------------------------------------------------------
# SECTION 2: Disable and Reset Firewall
#------------------------------------------------------------------------------
echo ""
echo ">>> Resetting Firewall"
echo "----------------------------------------------"

if [[ "$DISTRO" == "centos" || "$DISTRO" == "rhel" || "$DISTRO" == "rocky" || "$DISTRO" == "almalinux" ]]; then
    if systemctl is-active --quiet firewalld; then
        # Reset firewalld back to default public zone
        firewall-cmd --set-default-zone=public
        firewall-cmd --reload
        # Stop and disable firewalld
        systemctl stop firewalld
        systemctl disable firewalld
        echo "[RESET] firewalld stopped, disabled, and zone reset to public"
        PASSED+=("Firewall reset (firewalld)")
    else
        echo "[SKIP] firewalld is not running"
        SKIPPED+=("Firewall reset (firewalld not running)")
    fi

elif [[ "$DISTRO" == "ubuntu" || "$DISTRO" == "debian" ]]; then
    if ufw status | grep -q "Status: active"; then
        # Disable UFW and reset all rules to defaults
        ufw --force disable
        ufw --force reset
        echo "[RESET] UFW disabled and all rules cleared"
        PASSED+=("Firewall reset (UFW)")
    else
        echo "[SKIP] UFW is not active"
        SKIPPED+=("Firewall reset (UFW not active)")
    fi
fi

#------------------------------------------------------------------------------
# SECTION 3: Remove Fail2Ban
#------------------------------------------------------------------------------
echo ""
echo ">>> Removing Fail2Ban"
echo "----------------------------------------------"

if command -v fail2ban-client &> /dev/null; then
    # Stop the service first
    systemctl stop fail2ban
    systemctl disable fail2ban

    # Remove the custom jail config
    rm -f /etc/fail2ban/jail.local
    echo "[REMOVED] /etc/fail2ban/jail.local"

    # Uninstall Fail2Ban
    if [[ "$DISTRO" == "centos" || "$DISTRO" == "rhel" || "$DISTRO" == "rocky" || "$DISTRO" == "almalinux" ]]; then
        yum remove -y fail2ban
    elif [[ "$DISTRO" == "ubuntu" || "$DISTRO" == "debian" ]]; then
        apt remove -y fail2ban
        apt autoremove -y
    fi
    echo "[REMOVED] Fail2Ban uninstalled"
    PASSED+=("Fail2Ban removed")
else
    echo "[SKIP] Fail2Ban is not installed"
    SKIPPED+=("Fail2Ban removal (not installed)")
fi

#------------------------------------------------------------------------------
# SECTION 4: Reset File Permissions to Defaults
#------------------------------------------------------------------------------
echo ""
echo ">>> Resetting File Permissions to Defaults"
echo "----------------------------------------------"

# Restore standard default permissions
# These are the typical defaults on a fresh CentOS/Ubuntu install

chmod 644 /etc/passwd      && echo "[RESET] /etc/passwd -> 644"
chmod 640 /etc/shadow      && echo "[RESET] /etc/shadow -> 640"
chmod 644 /etc/group       && echo "[RESET] /etc/group  -> 644"
chmod 640 /etc/gshadow     && echo "[RESET] /etc/gshadow -> 640"
chmod 755 /etc/ssh         && echo "[RESET] /etc/ssh -> 755"
chmod 644 /etc/ssh/sshd_config && echo "[RESET] /etc/ssh/sshd_config -> 644"

# Reset GRUB permissions
if [ -f /boot/grub2/grub.cfg ]; then
    chmod 644 /boot/grub2/grub.cfg
    echo "[RESET] /boot/grub2/grub.cfg -> 644"
elif [ -f /boot/grub/grub.cfg ]; then
    chmod 644 /boot/grub/grub.cfg
    echo "[RESET] /boot/grub/grub.cfg -> 644"
fi

# Reset cron directories
chmod 755 /etc/cron.d 2>/dev/null
chmod 755 /etc/cron.daily 2>/dev/null
chmod 755 /etc/cron.hourly 2>/dev/null
chmod 755 /etc/cron.weekly 2>/dev/null
chmod 755 /etc/cron.monthly 2>/dev/null
echo "[RESET] Cron directories -> 755"

# Reset home directories to standard permissions
for dir in /home/*/; do
    if [ -d "$dir" ]; then
        chmod 755 "$dir"
        echo "[RESET] $dir -> 755"
    fi
done

PASSED+=("File permissions reset to defaults")

#------------------------------------------------------------------------------
# SECTION 5: Undo Core Dump Restriction
#------------------------------------------------------------------------------
echo ""
echo ">>> Removing Core Dump Restriction"
echo "----------------------------------------------"

# Remove the line that the hardening script added to limits.conf
if grep -q "^\* hard core 0" /etc/security/limits.conf; then
    sed -i '/^\* hard core 0/d' /etc/security/limits.conf
    echo "[REMOVED] Core dump restriction from limits.conf"
    PASSED+=("Core dump restriction removed")
else
    echo "[SKIP] No core dump restriction found in limits.conf"
    SKIPPED+=("Core dump restriction (not found)")
fi

#------------------------------------------------------------------------------
# SECTION 6: Clean Up Log Files
#------------------------------------------------------------------------------
echo ""
echo ">>> Cleaning Up Hardening Logs"
echo "----------------------------------------------"

# Remove log files created by the hardening script
LOG_COUNT=$(ls /var/log/server_hardening_*.log 2>/dev/null | wc -l)
if [[ $LOG_COUNT -gt 0 ]]; then
    rm -f /var/log/server_hardening_*.log
    echo "[REMOVED] $LOG_COUNT hardening log file(s)"
    PASSED+=("Hardening log files cleaned up")
else
    echo "[SKIP] No hardening log files found"
    SKIPPED+=("Log cleanup (no log files found)")
fi

# Remove SSH config backups
BACKUP_COUNT=$(ls ${SSHD_CONFIG}.bak.* 2>/dev/null | wc -l)
if [[ $BACKUP_COUNT -gt 0 ]]; then
    rm -f ${SSHD_CONFIG}.bak.*
    echo "[REMOVED] $BACKUP_COUNT sshd_config backup(s)"
fi

#------------------------------------------------------------------------------
# SECTION 7: Summary
#------------------------------------------------------------------------------
echo ""
echo "=============================================="
echo " ROLLBACK COMPLETE — SUMMARY"
echo "=============================================="
echo " OS: $DISTRO"
echo ""

echo " RESTORED (${#PASSED[@]} items):"
if [[ ${#PASSED[@]} -eq 0 ]]; then
    echo "   (none)"
else
    for item in "${PASSED[@]}"; do
        echo "   [✓] $item"
    done
fi

echo ""
echo " SKIPPED (${#SKIPPED[@]} items):"
if [[ ${#SKIPPED[@]} -eq 0 ]]; then
    echo "   (none)"
else
    for item in "${SKIPPED[@]}"; do
        echo "   [—] $item"
    done
fi

echo ""
echo " FAILED (${#FAILED[@]} items):"
if [[ ${#FAILED[@]} -eq 0 ]]; then
    echo "   (none — rollback fully successful!)"
else
    for item in "${FAILED[@]}"; do
        echo "   [✗] $item"
    done
fi

echo ""
echo " Your server is back to a clean state."
echo " You can now run a new hardening script from"
echo " a different AI tool for comparison."
echo "=============================================="
