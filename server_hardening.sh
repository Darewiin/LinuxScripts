#!/bin/bash
#==============================================================================
# Server Hardening Script
# Description: Automates basic security hardening for CentOS and Ubuntu servers
# Topics:      Firewall setup, SSH hardening, file permissions, system updates
# Generated:   By Claude AI (Anthropic) for cybersecurity coursework
# Usage:       sudo bash server_hardening.sh
#==============================================================================

#------------------------------------------------------------------------------
# SECTION 0: Pre-flight checks
# Purpose: Make sure the script is run with root privileges and detect the OS
#------------------------------------------------------------------------------

# Check if the script is being run as root (UID 0)
# Many hardening steps require root access to modify system configs
if [[ "$EUID" -ne 0 ]]; then
    echo "ERROR: This script must be run as root. Use: sudo bash $0"
    exit 1
fi

# Detect which distribution we're running on by reading /etc/os-release
# This lets us use the right package manager and firewall commands later
if [ -f /etc/os-release ]; then
    # Source the file to get variables like $ID
    . /etc/os-release
    DISTRO=$ID
else
    echo "ERROR: Cannot detect OS. /etc/os-release not found."
    exit 1
fi

echo "=============================================="
echo " Server Hardening Script"
echo " Detected OS: $DISTRO"
echo " Date: $(date)"
echo "=============================================="

# Create a log file to record everything the script does
LOGFILE="/var/log/server_hardening_$(date +%Y%m%d_%H%M%S).log"
exec > >(tee -a "$LOGFILE") 2>&1
echo "[INFO] Logging output to $LOGFILE"

# Arrays to track what passed and what failed for the summary report
PASSED=()
FAILED=()

#------------------------------------------------------------------------------
# SECTION 1: System Updates
# Purpose: Ensure all packages are up to date to patch known vulnerabilities
#------------------------------------------------------------------------------
echo ""
echo ">>> SECTION 1: Applying System Updates"
echo "----------------------------------------------"

if [[ "$DISTRO" == "centos" || "$DISTRO" == "rhel" || "$DISTRO" == "rocky" || "$DISTRO" == "almalinux" ]]; then
    # CentOS/RHEL family uses yum or dnf
    echo "[INFO] Updating packages with yum..."
    if yum update -y && yum install -y epel-release; then
        PASSED+=("System packages updated")
    else
        FAILED+=("System package updates (yum update failed)")
    fi
elif [[ "$DISTRO" == "ubuntu" || "$DISTRO" == "debian" ]]; then
    # Ubuntu/Debian family uses apt
    echo "[INFO] Updating packages with apt..."
    if apt update -y && apt upgrade -y; then
        PASSED+=("System packages updated")
    else
        FAILED+=("System package updates (apt upgrade failed)")
    fi
else
    echo "[WARN] Unsupported distro: $DISTRO. Skipping updates."
    FAILED+=("System package updates (unsupported distro: $DISTRO)")
fi

echo "[DONE] System updates complete."

#------------------------------------------------------------------------------
# SECTION 2: Firewall Configuration
# Purpose: Enable a firewall and allow only necessary traffic (SSH on port 22)
#------------------------------------------------------------------------------
echo ""
echo ">>> SECTION 2: Configuring Firewall"
echo "----------------------------------------------"

if [[ "$DISTRO" == "centos" || "$DISTRO" == "rhel" || "$DISTRO" == "rocky" || "$DISTRO" == "almalinux" ]]; then
    # CentOS uses firewalld by default
    echo "[INFO] Setting up firewalld..."
    
    # Install firewalld if not present
    yum install -y firewalld
    
    # Start and enable the firewalld service so it runs on boot
    systemctl start firewalld
    systemctl enable firewalld
    
    # Set the default zone to "drop" — this blocks all incoming traffic
    # that isn't explicitly allowed, which is the most secure default
    firewall-cmd --set-default-zone=drop
    
    # Allow SSH (port 22) so we don't lock ourselves out of the server
    firewall-cmd --zone=drop --add-service=ssh --permanent
    
    # Allow HTTP and HTTPS in case this is a web server
    # Comment these out if you don't need web traffic
    firewall-cmd --zone=drop --add-service=http --permanent
    firewall-cmd --zone=drop --add-service=https --permanent
    
    # Reload firewall rules to apply the permanent changes
    if firewall-cmd --reload; then
        PASSED+=("Firewall configured (firewalld)")
    else
        FAILED+=("Firewall configuration (firewalld reload failed)")
    fi
    
    # Display the current rules so we can verify
    echo "[INFO] Current firewall rules:"
    firewall-cmd --list-all

elif [[ "$DISTRO" == "ubuntu" || "$DISTRO" == "debian" ]]; then
    # Ubuntu uses UFW (Uncomplicated Firewall)
    echo "[INFO] Setting up UFW..."
    
    # Install UFW if not already installed
    apt install -y ufw
    
    # Set default policies: deny all incoming, allow all outgoing
    # This means only services we explicitly allow can receive connections
    ufw default deny incoming
    ufw default allow outgoing
    
    # Allow SSH so we don't get locked out
    ufw allow ssh
    
    # Allow HTTP and HTTPS for web servers
    # Comment these out if not needed
    ufw allow http
    ufw allow https
    
    # Enable UFW — the --force flag avoids the interactive prompt
    if ufw --force enable; then
        PASSED+=("Firewall configured (UFW)")
    else
        FAILED+=("Firewall configuration (UFW enable failed)")
    fi
    
    # Show the current status and rules
    echo "[INFO] Current UFW status:"
    ufw status verbose
fi

echo "[DONE] Firewall configuration complete."

#------------------------------------------------------------------------------
# SECTION 3: SSH Hardening
# Purpose: Secure the SSH service to prevent unauthorized remote access
#------------------------------------------------------------------------------
echo ""
echo ">>> SECTION 3: Hardening SSH Configuration"
echo "----------------------------------------------"

# The main SSH configuration file
SSHD_CONFIG="/etc/ssh/sshd_config"

# Back up the original config before making changes
cp "$SSHD_CONFIG" "${SSHD_CONFIG}.bak.$(date +%Y%m%d)"
echo "[INFO] Backed up sshd_config to ${SSHD_CONFIG}.bak.$(date +%Y%m%d)"

# Function to safely set a value in sshd_config
# It uncomments the line if commented out, or adds it if missing entirely
set_sshd_option() {
    local key="$1"
    local value="$2"
    # If the key exists (commented or not), replace the line
    if grep -qE "^\s*#?\s*${key}\b" "$SSHD_CONFIG"; then
        sed -i "s/^\s*#*\s*${key}\b.*/${key} ${value}/" "$SSHD_CONFIG"
    else
        # If the key doesn't exist at all, add it at the end
        echo "${key} ${value}" >> "$SSHD_CONFIG"
    fi
    echo "[SET] ${key} = ${value}"
}

# --- SSH Hardening Settings ---

# Disable root login over SSH
# Attackers commonly try to brute-force the root account
set_sshd_option "PermitRootLogin" "no"

# Use SSH Protocol 2 only (Protocol 1 has known vulnerabilities)
set_sshd_option "Protocol" "2"

# Set maximum authentication attempts to 3 before disconnecting
# This slows down brute-force attacks
set_sshd_option "MaxAuthTries" "3"

# Disable password authentication — use SSH keys instead
# SSH keys are much harder to brute-force than passwords
# NOTE: Make sure you have SSH key access set up BEFORE enabling this!
# For this lab, we'll leave password auth ON so you don't get locked out.
# To fully harden, change "yes" to "no" after setting up SSH keys.
set_sshd_option "PasswordAuthentication" "yes"

# Disable empty passwords — accounts with no password can't log in via SSH
set_sshd_option "PermitEmptyPasswords" "no"

# Set an idle timeout: disconnect SSH sessions after 5 minutes of inactivity
# ClientAliveInterval sends a keepalive every 300 seconds (5 min)
# ClientAliveCountMax 0 means disconnect immediately after interval
set_sshd_option "ClientAliveInterval" "300"
set_sshd_option "ClientAliveCountMax" "0"

# Disable X11 forwarding — prevents graphical apps from being forwarded
# This reduces the attack surface since most servers don't need GUIs
set_sshd_option "X11Forwarding" "no"

# Set a login grace period — user has 60 seconds to authenticate
# This prevents hanging connections from wasting server resources
set_sshd_option "LoginGraceTime" "60"

# Create a warning banner for anyone connecting via SSH
# This is a legal best practice — it warns unauthorized users
cat > /etc/ssh/banner << 'EOF'
*******************************************************************
*  WARNING: This system is for authorized users only.             *
*  All activity is monitored and logged.                          *
*  Unauthorized access is prohibited and will be prosecuted.      *
*******************************************************************
EOF

set_sshd_option "Banner" "/etc/ssh/banner"

# Restart the SSH service to apply changes
if [[ "$DISTRO" == "centos" || "$DISTRO" == "rhel" || "$DISTRO" == "rocky" || "$DISTRO" == "almalinux" ]]; then
    if systemctl restart sshd; then
        PASSED+=("SSH hardened and service restarted")
    else
        FAILED+=("SSH service restart (sshd failed to restart — check config syntax)")
    fi
elif [[ "$DISTRO" == "ubuntu" || "$DISTRO" == "debian" ]]; then
    if systemctl restart ssh; then
        PASSED+=("SSH hardened and service restarted")
    else
        FAILED+=("SSH service restart (ssh failed to restart — check config syntax)")
    fi
fi

echo "[DONE] SSH hardening complete."

#------------------------------------------------------------------------------
# SECTION 4: File Permission Hardening
# Purpose: Restrict access to sensitive system files and directories
#------------------------------------------------------------------------------
echo ""
echo ">>> SECTION 4: Hardening File Permissions"
echo "----------------------------------------------"

# Secure /etc/passwd — readable by all, writable only by root
# This file contains user account info (but not passwords)
if chmod 644 /etc/passwd; then
    echo "[SET] /etc/passwd permissions to 644 (rw-r--r--)"
else
    echo "[FAIL] Could not set /etc/passwd permissions"
    FAILED+=("File permissions: /etc/passwd")
fi

# Secure /etc/shadow — readable/writable only by root
# This file contains the actual hashed passwords
if chmod 600 /etc/shadow; then
    echo "[SET] /etc/shadow permissions to 600 (rw-------)"
else
    echo "[FAIL] Could not set /etc/shadow permissions"
    FAILED+=("File permissions: /etc/shadow")
fi

# Secure /etc/group — readable by all, writable only by root
if chmod 644 /etc/group; then
    echo "[SET] /etc/group permissions to 644 (rw-r--r--)"
else
    echo "[FAIL] Could not set /etc/group permissions"
    FAILED+=("File permissions: /etc/group")
fi

# Secure /etc/gshadow — readable/writable only by root
# Contains secure group information
if chmod 600 /etc/gshadow; then
    echo "[SET] /etc/gshadow permissions to 600 (rw-------)"
else
    echo "[FAIL] Could not set /etc/gshadow permissions"
    FAILED+=("File permissions: /etc/gshadow")
fi

# Secure the SSH configuration directory
# Only root should be able to read/modify SSH configs
if chmod 700 /etc/ssh; then
    echo "[SET] /etc/ssh permissions to 700 (rwx------)"
else
    echo "[FAIL] Could not set /etc/ssh permissions"
    FAILED+=("File permissions: /etc/ssh")
fi

# Secure the sshd_config file itself
if chmod 600 /etc/ssh/sshd_config; then
    echo "[SET] /etc/ssh/sshd_config permissions to 600 (rw-------)"
else
    echo "[FAIL] Could not set /etc/ssh/sshd_config permissions"
    FAILED+=("File permissions: /etc/ssh/sshd_config")
fi

# Track overall file permissions result
# If none of the above added to FAILED, count this section as passed
FILE_PERM_FAILURES=0
for item in "${FAILED[@]}"; do
    if [[ "$item" == File\ permissions* ]]; then
        ((FILE_PERM_FAILURES++))
    fi
done
if [[ $FILE_PERM_FAILURES -eq 0 ]]; then
    PASSED+=("Sensitive file permissions tightened")
fi

# Secure the bootloader config (GRUB) to prevent single-user mode attacks
if [ -f /boot/grub2/grub.cfg ]; then
    chmod 600 /boot/grub2/grub.cfg
    echo "[SET] /boot/grub2/grub.cfg permissions to 600"
elif [ -f /boot/grub/grub.cfg ]; then
    chmod 600 /boot/grub/grub.cfg
    echo "[SET] /boot/grub/grub.cfg permissions to 600"
fi

# Secure cron directories — only root should be able to schedule jobs
chmod 700 /etc/cron.d 2>/dev/null
chmod 700 /etc/cron.daily 2>/dev/null
chmod 700 /etc/cron.hourly 2>/dev/null
chmod 700 /etc/cron.weekly 2>/dev/null
chmod 700 /etc/cron.monthly 2>/dev/null
echo "[SET] Cron directories permissions to 700 (rwx------)"

echo "[DONE] File permission hardening complete."

#------------------------------------------------------------------------------
# SECTION 5: Additional Security Measures
# Purpose: Disable unnecessary services and enable security tools
#------------------------------------------------------------------------------
echo ""
echo ">>> SECTION 5: Additional Security Measures"
echo "----------------------------------------------"

# Install and enable Fail2Ban — blocks IPs after failed login attempts
echo "[INFO] Installing Fail2Ban..."
if [[ "$DISTRO" == "centos" || "$DISTRO" == "rhel" || "$DISTRO" == "rocky" || "$DISTRO" == "almalinux" ]]; then
    yum install -y fail2ban
elif [[ "$DISTRO" == "ubuntu" || "$DISTRO" == "debian" ]]; then
    apt install -y fail2ban
fi

# Check if Fail2Ban installed successfully
if ! command -v fail2ban-client &> /dev/null; then
    echo "[FAIL] Fail2Ban installation failed"
    FAILED+=("Fail2Ban installation")
else

# Create a basic Fail2Ban jail configuration for SSH
cat > /etc/fail2ban/jail.local << 'EOF'
[DEFAULT]
# Ban IP for 1 hour (3600 seconds) after failed attempts
bantime  = 3600
# Look at the last 10 minutes of logs for failures
findtime = 600
# Allow 5 failed attempts before banning
maxretry = 5

[sshd]
enabled = true
port    = ssh
logpath = %(sshd_log)s
backend = %(sshd_backend)s
EOF

# Start and enable Fail2Ban
    if systemctl start fail2ban && systemctl enable fail2ban; then
        PASSED+=("Fail2Ban installed and configured")
    else
        FAILED+=("Fail2Ban service start (installed but failed to start)")
    fi
    echo "[DONE] Fail2Ban installed and configured."
fi

# Disable core dumps — prevents sensitive data from being written to disk
# when a program crashes
if echo "* hard core 0" >> /etc/security/limits.conf; then
    PASSED+=("Core dumps disabled")
    echo "[SET] Core dumps disabled via limits.conf"
else
    FAILED+=("Core dumps (could not write to limits.conf)")
    echo "[FAIL] Could not disable core dumps"
fi

# Set secure permissions on user home directories
# Each user's home directory should only be accessible by that user
echo "[INFO] Securing home directory permissions..."
HOME_DIR_FAIL=0
for dir in /home/*/; do
    if [ -d "$dir" ]; then
        if chmod 700 "$dir"; then
            echo "[SET] $dir permissions to 700"
        else
            echo "[FAIL] Could not set permissions on $dir"
            ((HOME_DIR_FAIL++))
        fi
    fi
done
if [[ $HOME_DIR_FAIL -eq 0 ]]; then
    PASSED+=("Home directories secured")
else
    FAILED+=("Home directory permissions ($HOME_DIR_FAIL directories failed)")
fi

echo "[DONE] Additional security measures complete."

#------------------------------------------------------------------------------
# SECTION 6: Summary Report
# Purpose: Display what passed and what failed for documentation
#------------------------------------------------------------------------------
echo ""
echo "=============================================="
echo " HARDENING COMPLETE — SUMMARY"
echo "=============================================="
echo " OS Detected:            $DISTRO"
echo " Log File:               $LOGFILE"
echo " SSH Config Backup:      ${SSHD_CONFIG}.bak.$(date +%Y%m%d)"
echo ""

# Display all items that passed
echo " PASSED (${#PASSED[@]} items):"
if [[ ${#PASSED[@]} -eq 0 ]]; then
    echo "   (none)"
else
    for item in "${PASSED[@]}"; do
        echo "   [✓] $item"
    done
fi

echo ""

# Display all items that failed
echo " FAILED (${#FAILED[@]} items):"
if [[ ${#FAILED[@]} -eq 0 ]]; then
    echo "   (none — everything passed!)"
else
    for item in "${FAILED[@]}"; do
        echo "   [✗] $item"
    done
fi

echo ""
echo " IMPORTANT NEXT STEPS:"
echo "   1. Set up SSH key-based authentication"
echo "   2. Then change PasswordAuthentication to 'no' in sshd_config"
echo "   3. Review /var/log/fail2ban.log for blocked IPs"
echo "   4. Test SSH access BEFORE closing your current session"

# If anything failed, suggest reviewing the log
if [[ ${#FAILED[@]} -gt 0 ]]; then
    echo ""
    echo " ⚠ SOME STEPS FAILED — review the log file for details:"
    echo "   cat $LOGFILE"
fi

echo "=============================================="
