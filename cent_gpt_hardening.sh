#!/bin/bash

#############################################
# HARDENING SCRIPT (FINAL VERSION)
# - Ubuntu (ufw)
# - CentOS (firewalld / iptables)
# - SELinux-aware
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

#############################################
# ROOT CHECK
#############################################
if [[ $EUID -ne 0 ]]; then
   echo "Run as root"
   exit 1
fi

#############################################
# OS DETECTION
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
# FIREWALL CONFIG
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

    if systemctl is-active firewalld >/dev/null 2>&1; then

        echo "Using firewalld"

        firewall-cmd --permanent --add-service=ssh
        log_result $? "Allow SSH (firewalld)"

        firewall-cmd --reload
        log_result $? "Reload firewalld"

        FIREWALL_TYPE="firewalld"

    else
        echo "firewalld not active, using iptables"

        iptables-save > /root/iptables.bak
        log_result $? "Backup iptables"

        iptables -P INPUT DROP
        iptables -P OUTPUT ACCEPT

        iptables -A INPUT -i lo -j ACCEPT
        iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
        iptables -A INPUT -p tcp --dport 22 -j ACCEPT

        log_result $? "Configured iptables rules"

        FIREWALL_TYPE="iptables"
    fi
fi

#############################################
# SSH HARDENING (SELINUX SAFE)
#############################################
echo "Hardening SSH..."

SSH_CONFIG="/etc/ssh/sshd_config"
cp $SSH_CONFIG ${SSH_CONFIG}.bak
log_result $? "Backup SSH config"

# Enable key auth
sed -i 's/^#PubkeyAuthentication yes/PubkeyAuthentication yes/' $SSH_CONFIG
sed -i 's/^PubkeyAuthentication no/PubkeyAuthentication yes/' $SSH_CONFIG

# Disable root login
sed -i 's/^#PermitRootLogin yes/PermitRootLogin no/' $SSH_CONFIG
sed -i 's/^PermitRootLogin yes/PermitRootLogin no/' $SSH_CONFIG
log_result $? "Disable root login"

# Disable password auth ONLY if key exists
if [ -f ~/.ssh/authorized_keys ]; then
    sed -i 's/^#PasswordAuthentication yes/PasswordAuthentication no/' $SSH_CONFIG
    sed -i 's/^PasswordAuthentication yes/PasswordAuthentication no/' $SSH_CONFIG
    log_result $? "Disable password auth"
else
    log_result 1 "Skipped password auth disable (no keys)"
fi

#############################################
# OPEN NEW SSH PORT IN FIREWALL
#############################################

if [[ "$FIREWALL_TYPE" == "firewalld" ]]; then
    firewall-cmd --permanent --add-port=2222/tcp
    firewall-cmd --reload
elif [[ "$FIREWALL_TYPE" == "iptables" ]]; then
    iptables -A INPUT -p tcp --dport 2222 -j ACCEPT
fi

#############################################
# SELINUX CONFIG (CRITICAL FIX)
#############################################

if command -v getenforce >/dev/null 2>&1; then
    if [[ "$(getenforce)" == "Enforcing" ]]; then

        echo "Configuring SELinux for new SSH port..."

        yum install -y policycoreutils-python-utils >/dev/null 2>&1 || \
        dnf install -y policycoreutils-python-utils >/dev/null 2>&1

        semanage port -a -t ssh_port_t -p tcp 2222 2>/dev/null || \
        semanage port -m -t ssh_port_t -p tcp 2222

        log_result $? "Allow SSH port 2222 in SELinux"
    fi
fi

#############################################
# CLEAN SSH PORT CONFIG
#############################################

sed -i '/^Port /d' $SSH_CONFIG
echo "Port 2222" >> $SSH_CONFIG
log_result $? "Set SSH port to 2222"

#############################################
# VALIDATE + RESTART SSH
#############################################

if sshd -t 2>/dev/null; then
    if [[ "$OS" == "ubuntu" ]]; then
        systemctl restart ssh
    else
        systemctl restart sshd
    fi
    log_result $? "Restart SSH"
else
    echo "SSH config invalid — restoring backup"
    cp ${SSH_CONFIG}.bak $SSH_CONFIG
    systemctl restart sshd
    log_result 1 "SSH failed — rollback applied"
fi

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
