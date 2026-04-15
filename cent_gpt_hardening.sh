#!/bin/bash

#############################################
# HARDENING SCRIPT (v2 - Smart Firewall Logic)
#############################################

PASS_COUNT=0
FAIL_COUNT=0
RESULTS=()

log_result() {
    if [ $1 -eq 0 ]; then
        echo "[PASS] $2"
        RESULTS+=("[PASS] $2")
        ((PASS_COUNT++))
    else
        echo "[FAIL] $2"
        RESULTS+=("[FAIL] $2")
        ((FAIL_COUNT++))
    fi
}

# Root check
if [[ $EUID -ne 0 ]]; then
   echo "Run as root"
   exit 1
fi

# Detect OS
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
# FIREWALL CONFIGURATION
#############################################

echo "Configuring firewall..."

if [[ "$OS" == "ubuntu" ]]; then

    apt update -y
    log_result $? "Update packages"

    apt install ufw -y
    log_result $? "Install UFW"

    ufw default deny incoming
    log_result $? "Deny incoming"

    ufw default allow outgoing
    log_result $? "Allow outgoing"

    ufw allow 22/tcp
    log_result $? "Allow SSH"

    ufw --force enable
    log_result $? "Enable UFW"

elif [[ "$OS" == "centos" ]]; then

    # Detect firewalld
    if systemctl is-active firewalld >/dev/null 2>&1; then

        echo "Using firewalld"

        firewall-cmd --permanent --add-service=ssh
        log_result $? "Allow SSH (firewalld)"

        firewall-cmd --reload
        log_result $? "Reload firewalld"

        FIREWALL_TYPE="firewalld"

    else
        echo "firewalld not active, using iptables"

        # Save backup of current rules
        iptables-save > /root/iptables.bak
        log_result $? "Backup iptables"

        # Safe baseline rules
        iptables -P INPUT DROP
        iptables -P OUTPUT ACCEPT

        # Allow loopback (critical)
        iptables -A INPUT -i lo -j ACCEPT

        # Allow established connections
        iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

        # Allow SSH
        iptables -A INPUT -p tcp --dport 22 -j ACCEPT

        log_result $? "Configured iptables rules"

        FIREWALL_TYPE="iptables"
    fi
fi

#############################################
# SSH HARDENING
#############################################

echo "Hardening SSH..."

SSH_CONFIG="/etc/ssh/sshd_config"
cp $SSH_CONFIG ${SSH_CONFIG}.bak
log_result $? "Backup SSH config"

sed -i 's/^#PermitRootLogin yes/PermitRootLogin no/' $SSH_CONFIG
sed -i 's/^PermitRootLogin yes/PermitRootLogin no/' $SSH_CONFIG
log_result $? "Disable root login"

sed -i 's/^#PasswordAuthentication yes/PasswordAuthentication no/' $SSH_CONFIG
sed -i 's/^PasswordAuthentication yes/PasswordAuthentication no/' $SSH_CONFIG
log_result $? "Disable password auth"

# Open port BEFORE changing it (important)
if [[ "$FIREWALL_TYPE" == "firewalld" ]]; then
    firewall-cmd --permanent --add-port=2222/tcp
    firewall-cmd --reload
elif [[ "$FIREWALL_TYPE" == "iptables" ]]; then
    iptables -A INPUT -p tcp --dport 2222 -j ACCEPT
fi

sed -i 's/^#Port 22/Port 2222/' $SSH_CONFIG
log_result $? "Change SSH port"

# Restart SSH
if [[ "$OS" == "ubuntu" ]]; then
    systemctl restart ssh
else
    systemctl restart sshd
fi
log_result $? "Restart SSH"

#############################################
# FILE PERMISSIONS
#############################################

chmod 644 /etc/passwd
log_result $? "/etc/passwd perms"

chmod 600 /etc/shadow
log_result $? "/etc/shadow perms"

chmod -R go-rwx /home/*
log_result $? "/home perms"

#############################################
# SUMMARY
#############################################

echo "===== SUMMARY ====="
for r in "${RESULTS[@]}"; do echo "$r"; done

echo "PASS: $PASS_COUNT"
echo "FAIL: $FAIL_COUNT"

exit $FAIL_COUNT
