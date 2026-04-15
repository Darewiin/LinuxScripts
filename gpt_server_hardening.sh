#!/bin/bash
# ↑ Shebang: tells the OS to execute this script using Bash shell
# REF: https://linux.die.net/man/1/bash

#############################################
# Cybersecurity Server Hardening Script
# Supports: Ubuntu (ufw) & CentOS (firewalld)
# Covers:
#   - Firewall setup
#   - SSH hardening
#   - File permissions
#   - Pass/Fail summary
#############################################

# ===============================
# GLOBAL VARIABLES
# ===============================

PASS_COUNT=0
# Counter for successful operations (0 = initial value)

FAIL_COUNT=0
# Counter for failed operations

RESULTS=()
# Bash array to store results of each step (PASS/FAIL messages)
# REF: https://www.gnu.org/software/bash/manual/html_node/Arrays.html

# ===============================
# FUNCTION: log_result
# ===============================
log_result() {
    # $1 = exit code of previous command
    # $2 = descriptive message

    if [ $1 -eq 0 ]; then
        # -eq = numeric comparison (equal)
        # In Linux, exit code 0 = success
        # REF: https://tldp.org/LDP/abs/html/exit-status.html

        echo "[PASS] $2"
        # Print success message

        RESULTS+=("[PASS] $2")
        # Append message to RESULTS array

        ((PASS_COUNT++))
        # Increment PASS counter using arithmetic expansion

    else
        echo "[FAIL] $2"
        # Print failure message

        RESULTS+=("[FAIL] $2")
        # Append failure message

        ((FAIL_COUNT++))
        # Increment FAIL counter
    fi
}

# ===============================
# CHECK ROOT PRIVILEGES
# ===============================
if [[ $EUID -ne 0 ]]; then
# $EUID = Effective User ID
# 0 = root user
# -ne = not equal

   echo "Please run as root (sudo)"
   # Inform user they need elevated privileges

   exit 1
   # Exit script with error code (non-zero = failure)
fi

# ===============================
# DETECT OPERATING SYSTEM
# ===============================
source /etc/os-release
# source = executes file in current shell
# /etc/os-release contains OS metadata (ID, version, etc.)
# REF: https://www.freedesktop.org/software/systemd/man/os-release.html

if [[ "$ID" == "ubuntu" ]]; then
    OS="ubuntu"
    # Assign variable if Ubuntu

elif [[ "$ID" == "centos" || "$ID_LIKE" == *"rhel"* ]]; then
    OS="centos"
    # Covers CentOS and RHEL-based systems using wildcard match (*)

else
    echo "Unsupported OS"
    exit 1
fi

echo "Detected OS: $OS"
# Print detected OS for visibility/debugging

# ===============================
# FIREWALL SETUP
# ===============================
echo "Configuring firewall..."

if [[ "$OS" == "ubuntu" ]]; then

    apt update -y
    # Updates package list from repositories
    # -y = auto-confirm prompts

    log_result $? "Update package list"

    apt install ufw -y
    # Installs UFW (Uncomplicated Firewall)
    # REF: https://help.ubuntu.com/community/UFW

    log_result $? "Install UFW"

    ufw default deny incoming
    # Blocks all incoming connections by default
    # Principle: Default Deny (least privilege)

    log_result $? "UFW deny incoming"

    ufw default allow outgoing
    # Allows all outgoing traffic (needed for updates, DNS, etc.)

    log_result $? "UFW allow outgoing"

    ufw allow 22/tcp
    # Allows SSH connections on port 22 using TCP protocol

    log_result $? "Allow SSH (22)"

    ufw --force enable
    # Enables firewall without interactive prompt

    log_result $? "Enable UFW"

elif [[ "$OS" == "centos" ]]; then

    yum install firewalld -y
    # Installs firewalld (default firewall for CentOS/RHEL)

    log_result $? "Install firewalld"

    systemctl start firewalld
    # Starts firewall service immediately

    log_result $? "Start firewalld"

    systemctl enable firewalld
    # Ensures firewall starts on boot

    log_result $? "Enable firewalld"

    firewall-cmd --set-default-zone=public
    # Sets default firewall zone (defines trust level)

    log_result $? "Set default zone"

    firewall-cmd --permanent --add-service=ssh
    # Opens SSH service permanently
    # --permanent = persists after reboot

    log_result $? "Allow SSH"

    firewall-cmd --reload
    # Applies changes

    log_result $? "Reload firewall"
fi

# ===============================
# SSH HARDENING
# ===============================
echo "Hardening SSH..."

SSH_CONFIG="/etc/ssh/sshd_config"
# Path to SSH daemon configuration file

cp $SSH_CONFIG ${SSH_CONFIG}.bak
# Backup original config before modifying
# Good practice in system administration

log_result $? "Backup SSH config"

sed -i 's/^#PermitRootLogin yes/PermitRootLogin no/' $SSH_CONFIG
# sed = stream editor
# -i = edit file in-place
# Replaces commented line disabling root login

sed -i 's/^PermitRootLogin yes/PermitRootLogin no/' $SSH_CONFIG
# Handles case where line is already uncommented

log_result $? "Disable root login"

sed -i 's/^#PasswordAuthentication yes/PasswordAuthentication no/' $SSH_CONFIG
# Disables password authentication (forces SSH keys)

sed -i 's/^PasswordAuthentication yes/PasswordAuthentication no/' $SSH_CONFIG
# Handles uncommented case

log_result $? "Disable password authentication"

sed -i 's/^#Port 22/Port 2222/' $SSH_CONFIG
# Changes default SSH port (reduces automated scanning attacks)

log_result $? "Change SSH port to 2222"

if [[ "$OS" == "ubuntu" ]]; then
    systemctl restart ssh
    # Restart SSH service (Ubuntu uses 'ssh')

else
    systemctl restart sshd
    # Restart SSH daemon (CentOS uses 'sshd')
fi

log_result $? "Restart SSH service"

# ===============================
# FILE PERMISSIONS HARDENING
# ===============================
echo "Setting secure permissions..."

chmod 644 /etc/passwd
# Owner: read/write (6)
# Group: read (4)
# Others: read (4)
# /etc/passwd must be readable system-wide

log_result $? "Set /etc/passwd permissions (644)"

chmod 600 /etc/shadow
# Owner: read/write (6)
# Group: no access (0)
# Others: no access (0)
# Protects hashed passwords

log_result $? "Set /etc/shadow permissions (600)"

chmod -R go-rwx /home/*
# -R = recursive
# go = group + others
# rwx = remove read, write, execute
# Restricts access to user home directories

log_result $? "Restrict /home directories"

# ===============================
# FINAL SUMMARY
# ===============================
echo ""
echo "==============================="
echo "HARDENING SUMMARY"
echo "==============================="

for result in "${RESULTS[@]}"; do
# Loop through array elements

    echo "$result"
    # Print each result
done

echo ""
echo "Total PASS: $PASS_COUNT"
# Display total successes

echo "Total FAIL: $FAIL_COUNT"
# Display total failures

if [ $FAIL_COUNT -gt 0 ]; then
# -gt = greater than

    exit 1
    # Return failure if any step failed

else
    exit 0
    # Return success if all steps passed
fi
