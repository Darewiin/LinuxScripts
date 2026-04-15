#!/bin/bash

#############################################
# ROLLBACK SCRIPT (FINAL VERSION)
#############################################

RESTORE=0
FAIL=0
SKIP=0
RESULTS=()

#############################################
# LOG FUNCTION
#############################################
log() {
    echo "[$1] $2"
    RESULTS+=("[$1] $2")

    case $1 in
        RESTORED) ((RESTORE++)) ;;
        FAILED) ((FAIL++)) ;;
        SKIPPED) ((SKIP++)) ;;
    esac
}

#############################################
# ROOT CHECK
#############################################
if [[ $EUID -ne 0 ]]; then
    echo "Run as root"
    exit 1
fi

#############################################
# FIREWALL RESTORE
#############################################

echo "Restoring firewall..."

if systemctl is-active firewalld >/dev/null 2>&1; then

    firewall-cmd --permanent --remove-port=2222/tcp
    firewall-cmd --permanent --remove-service=ssh
    firewall-cmd --reload

    log RESTORED "firewalld rules reverted"

elif [[ -f /root/iptables.bak ]]; then

    iptables-restore < /root/iptables.bak
    # Restores previous iptables rules

    log RESTORED "iptables restored"

else
    log SKIPPED "No firewall backup found"
fi

#############################################
# SELINUX CLEANUP
#############################################

if command -v getenforce >/dev/null 2>&1; then
    if [[ "$(getenforce)" == "Enforcing" ]]; then

        semanage port -d -t ssh_port_t -p tcp 2222 2>/dev/null
        # Removes custom SSH port rule

        log RESTORED "Removed SELinux rule"
    fi
fi

#############################################
# SSH RESTORE
#############################################

SSH_CONFIG="/etc/ssh/sshd_config"
BACKUP="${SSH_CONFIG}.bak"

if [[ -f "$BACKUP" ]]; then
    cp "$BACKUP" "$SSH_CONFIG"
    log RESTORED "SSH config restored"

    systemctl restart ssh 2>/dev/null || systemctl restart sshd
    log RESTORED "SSH restarted"
else
    log FAILED "SSH backup missing"
fi

#############################################
# FILE PERMISSIONS RESTORE
#############################################

chmod 644 /etc/passwd
log RESTORED "/etc/passwd reset"

chmod 640 /etc/shadow
log RESTORED "/etc/shadow reset"

chmod -R 755 /home/*
log RESTORED "/home reset"

#############################################
# SUMMARY
#############################################

echo "===== ROLLBACK SUMMARY ====="
for r in "${RESULTS[@]}"; do echo "$r"; done

echo "RESTORED: $RESTORE"
echo "FAILED: $FAIL"
echo "SKIPPED: $SKIP"

exit $FAIL
