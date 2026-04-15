#!/bin/bash
# Shebang → tells system to use Bash interpreter

#############################################
# HARDENING SCRIPT (FINAL VERSION)
# Supports:
# - Ubuntu (ufw)
# - CentOS (firewalld / iptables)
# - SELinux-aware SSH configuration
#############################################

PASS_COUNT=0        # Counter for successful steps
FAIL_COUNT=0        # Counter for failed steps
RESULTS=()          # Array to store results for summary

#############################################
# FUNCTION: log_result
# Logs PASS/FAIL and updates counters
#############################################
log_result() {
    if [ $1 -eq 0 ]; then
        # Exit code 0 = success
        echo "[PASS] $2"
        RESULTS+=("[PASS] $2")
        ((PASS_COUNT++))
    else
        # Non-zero = failure
        echo "[FAIL] $2"
        RESULTS+=("[FAIL] $2")
        ((FAIL_COUNT++))
    fi
}

#############################################
# ROOT CHECK
# Many system operations require root privileges
#############################################
if [[ $EUID -ne 0 ]]; then
   echo "Run as root"
   exit 1
fi

#############################################
# OS DETECTION
# Uses /etc/os-release to identify distribution
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
# FIREWALL CONFIGURATION
#############################################
echo "Configuring firewall..."

if [[ "$OS" == "ubuntu" ]]; then

    apt update -y
    # Updates package index
    log_result $? "Update packages"

    apt install ufw -y
    # Installs UFW firewall
    log_result $? "Install UFW"

    ufw default deny incoming
    # Blocks all incoming connections by default
    log_result $? "Deny incoming"

    ufw default allow outgoing
    # Allows outgoing traffic
    log_result $? "Allow outgoing"

    ufw allow 22/tcp
    # Allows SSH on port 22
    log_result $? "Allow SSH"

    ufw --force enable
    # Enables firewall without prompt
    log_result $? "Enable UFW"

elif [[ "$OS" == "centos" ]]; then

    # Check if firewalld is active
    if systemctl is-active firewalld >/dev/null 2>&1; then

        echo "Using firewalld"

        firewall-cmd --permanent --add-service=ssh
        # Allows SSH service permanently
        log_result $? "Allow SSH (firewalld)"

        firewall-cmd --reload
        # Applies firewall changes
        log_result $? "Reload firewalld"

        FIREWALL_TYPE="firewalld"

    else
        echo "firewalld not active, using iptables"

        iptables-save > /root/iptables.bak
        # Backup current iptables rules
        log_result $? "Backup iptables"

        iptables -P INPUT DROP
        # Default policy: block all incoming

        iptables -P OUTPUT ACCEPT
        # Allow all outgoing

        iptables -A INPUT -i lo -j ACCEPT
        # Allow loopback traffic (critical for system operations)

        iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
        # Allow existing connections (prevents disconnecting yourself)

        iptables -A INPUT -p tcp --dport 22 -j ACCEPT
        # Allow SSH access

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
# Backup original config before modification
log_result $? "Backup SSH config"

# Enable public key authentication
sed -i 's/^#PubkeyAuthentication yes/PubkeyAuthentication yes/' $SSH_CONFIG
sed -i 's/^PubkeyAuthentication no/PubkeyAuthentication yes/' $SSH_CONFIG

# Disable root login
sed -i 's/^#PermitRootLogin yes/PermitRootLogin no/' $SSH_CONFIG
sed -i 's/^PermitRootLogin yes/PermitRootLogin no/' $SSH_CONFIG
log_result $? "Disable root login"

# Disable password authentication ONLY if SSH keys exist
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
# SELINUX CONFIGURATION
#############################################

if command -v getenforce >/dev/null 2>&1; then
    if [[ "$(getenforce)" == "Enforcing" ]]; then

        echo "Configuring SELinux for SSH port..."

        yum install -y policycoreutils-python-utils >/dev/null 2>&1 || \
        dnf install -y policycoreutils-python-utils >/dev/null 2>&1
        # Installs semanage tool if missing

        semanage port -a -t ssh_port_t -p tcp 2222 2>/dev/null || \
        semanage port -m -t ssh_port_t -p tcp 2222
        # Adds or modifies allowed SSH port in SELinux

        log_result $? "Allow SSH port 2222 in SELinux"
    fi
fi

#############################################
# CLEAN SSH PORT CONFIG
#############################################

sed -i '/^Port /d' $SSH_CONFIG
# Removes all existing Port lines

echo "Port 2222" >> $SSH_CONFIG
# Adds clean port configuration
log_result $? "Set SSH port to 2222"

#############################################
# VALIDATE + RESTART SSH
#############################################

if sshd -t 2>/dev/null; then
    # sshd -t validates configuration syntax

    if [[ "$OS" == "ubuntu" ]]; then
        systemctl restart ssh
    else
        systemctl restart sshd
    fi

    log_result $? "Restart SSH"

else
    echo "SSH config invalid — restoring backup"

    cp ${SSH_CONFIG}.bak $SSH_CONFIG
    # Restore backup if config invalid

    systemctl restart sshd
    log_result 1 "SSH failed — rollback applied"
fi

#############################################
# FILE PERMISSIONS HARDENING
#############################################

chmod 644 /etc/passwd
# Readable by system, writable by root
log_result $? "/etc/passwd perms"

chmod 600 /etc/shadow
# Only root can read/write (contains password hashes)
log_result $? "/etc/shadow perms"

chmod -R go-rwx /home/*
# Removes access for group/others from home dirs
log_result $? "/home perms"

#############################################
# SUMMARY OUTPUT
#############################################

echo "===== SUMMARY ====="
for r in "${RESULTS[@]}"; do echo "$r"; done

echo "PASS: $PASS_COUNT"
echo "FAIL: $FAIL_COUNT"

exit $FAIL_COUNT
