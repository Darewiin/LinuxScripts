#!/bin/bash
# Rollback Script for Server Hardening
# Restores firewall, SSH config, and file permissions

#############################################
# GLOBAL VARIABLES
#############################################

RESTORE_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0

RESULTS=()

#############################################
# FUNCTION: log_result
#############################################
log_result() {
    # $1 = exit code
    # $2 = message
    # $3 = status type (RESTORED / FAILED / SKIPPED)

    case $3 in
        "RESTORED")
            echo "[RESTORED] $2"
            RESULTS+=("[RESTORED] $2")
            ((RESTORE_COUNT++))
            ;;
        "FAILED")
            echo "[FAILED] $2"
            RESULTS+=("[FAILED] $2")
            ((FAIL_COUNT++))
            ;;
        "SKIPPED")
            echo "[SKIPPED] $2"
            RESULTS+=("[SKIPPED] $2")
            ((SKIP_COUNT++))
            ;;
    esac
}

#############################################
# CHECK ROOT
#############################################
if [[ $EUID -ne 0 ]]; then
    echo "Run as root (sudo)"
    exit 1
fi

#############################################
# DETECT OS
#############################################
source /etc/os-release

if [[ "$ID" == "ubuntu" ]]; then
    OS="ubuntu"
elif [[ "$ID" == "centos" || "$ID_LIKE" == *"rhel"* ]]; then
    OS="centos"
else
    echo "Unsupported OS"
    exit 1
fi

echo "Detected OS: $OS"

#############################################
# FIREWALL ROLLBACK
#############################################
echo "Rolling back firewall..."

if [[ "$OS" == "ubuntu" ]]; then

    if command -v ufw >/dev/null 2>&1; then
        ufw --force reset
        # Resets UFW to default state (removes all rules)

        log_result $? "Reset UFW to defaults" "RESTORED"

    else
        log_result 1 "UFW not installed" "SKIPPED"
    fi

elif [[ "$OS" == "centos" ]]; then

    if systemctl is-active firewalld >/dev/null 2>&1; then
        firewall-cmd --complete-reload
        # Reload full configuration

        firewall-cmd --permanent --remove-service=ssh
        # Remove SSH rule added earlier

        firewall-cmd --reload
        # Apply changes

        log_result $? "Reset firewalld rules" "RESTORED"

    else
        log_result 1 "firewalld not active" "SKIPPED"
    fi
fi

#############################################
# SSH CONFIG ROLLBACK
#############################################
echo "Restoring SSH config..."

SSH_CONFIG="/etc/ssh/sshd_config"
BACKUP="${SSH_CONFIG}.bak"

if [[ -f "$BACKUP" ]]; then
    cp "$BACKUP" "$SSH_CONFIG"
    # Restore original config

    log_result $? "Restore SSH config from backup" "RESTORED"

    if [[ "$OS" == "ubuntu" ]]; then
        systemctl restart ssh
    else
        systemctl restart sshd
    fi

    log_result $? "Restart SSH service" "RESTORED"

else
    log_result 1 "SSH backup not found, cannot restore" "FAILED"
fi

#############################################
# FILE PERMISSIONS ROLLBACK
#############################################
echo "Restoring file permissions..."

chmod 644 /etc/passwd
# Usually already correct, reapply standard

log_result $? "Restore /etc/passwd permissions" "RESTORED"

chmod 640 /etc/shadow
# Common default (root readable, group readable)

log_result $? "Restore /etc/shadow permissions" "RESTORED"

chmod -R 755 /home/*
# Restore typical default (owner full, others read/execute)

log_result $? "Restore /home permissions" "RESTORED"

#############################################
# SUMMARY
#############################################
echo ""
echo "==============================="
echo "ROLLBACK SUMMARY"
echo "==============================="

for result in "${RESULTS[@]}"; do
    echo "$result"
done

echo ""
echo "Total RESTORED: $RESTORE_COUNT"
echo "Total FAILED: $FAIL_COUNT"
echo "Total SKIPPED: $SKIP_COUNT"

# Exit with failure if any failures occurred
if [ $FAIL_COUNT -gt 0 ]; then
    exit 1
else
    exit 0
fi
