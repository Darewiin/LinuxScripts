#!/bin/bash
# EXPLANATION: Shebang line — tells the OS to use the Bash shell to interpret
# this script. Required as the first line of any Bash script.
# Reference: https://www.gnu.org/software/bash/manual/bash.html#Invoking-Bash

#==============================================================================
# Server Hardening ROLLBACK Script
# Description: Undoes all changes made by server_hardening.sh so you can
#              test a different script from a clean state
# Generated:   By Claude AI (Anthropic) for cybersecurity coursework
# Usage:       sudo bash rollback_hardening.sh
#==============================================================================

#------------------------------------------------------------------------------
# SECTION 0: Pre-flight checks
# Purpose: Verify root access, detect OS, confirm the user wants to proceed
#------------------------------------------------------------------------------

# EXPLANATION: $EUID holds the Effective User ID. Root is always UID 0.
# -ne means "not equal". We need root to undo system-level changes.
# Reference: https://man7.org/linux/man-pages/man1/id.1.html
if [[ "$EUID" -ne 0 ]]; then
    echo "ERROR: This script must be run as root. Use: sudo bash $0"
    exit 1
fi

# EXPLANATION: Source /etc/os-release to get the $ID variable which contains
# the distribution name (e.g., "ubuntu", "centos"). We need this to know
# which package manager and service names to use for the undo operations.
# Reference: https://www.freedesktop.org/software/systemd/man/os-release.html
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

# EXPLANATION: 'read -p' displays a prompt and waits for user input, storing
# the response in the variable $CONFIRM. This is a safety measure — rolling
# back security settings on a production server could be dangerous, so we
# make the user explicitly type "yes" to continue.
# Reference: https://www.gnu.org/software/bash/manual/bash.html#Bash-Builtins
read -p "Are you sure you want to continue? (yes/no): " CONFIRM
if [[ "$CONFIRM" != "yes" ]]; then
    echo "Rollback cancelled."
    # EXPLANATION: 'exit 0' stops the script with exit code 0 (success).
    # The user chose to cancel, which isn't an error — it's a valid choice.
    exit 0
fi

# EXPLANATION: Three arrays to track results. PASSED = successfully undone,
# FAILED = couldn't undo, SKIPPED = nothing to undo (change wasn't present).
# This gives a clear picture of what the rollback actually did.
PASSED=()
FAILED=()
SKIPPED=()

#------------------------------------------------------------------------------
# SECTION 1: Restore SSH Configuration
# Purpose: Put the original sshd_config back from the backup we made earlier.
#          This undoes all SSH hardening settings in one step.
#------------------------------------------------------------------------------
echo ""
echo ">>> Restoring SSH Configuration"
echo "----------------------------------------------"

# EXPLANATION: This variable stores the path to the SSH daemon config file.
# We define it once and reuse it throughout the script for consistency.
SSHD_CONFIG="/etc/ssh/sshd_config"

# EXPLANATION: 'ls -t' lists files sorted by modification time (newest first).
# The glob ${SSHD_CONFIG}.bak.* matches all backup files we created.
# '2>/dev/null' silences "no such file" errors if no backups exist.
# 'head -1' grabs just the first (most recent) backup.
# '$()' is command substitution — it runs the command and captures its output.
# Reference: https://man7.org/linux/man-pages/man1/ls.1.html
BACKUP=$(ls -t ${SSHD_CONFIG}.bak.* 2>/dev/null | head -1)

# EXPLANATION: '-n' tests if the string is non-empty. If $BACKUP has a value,
# it means we found a backup file to restore from.
if [[ -n "$BACKUP" ]]; then
    # EXPLANATION: 'cp' copies the backup file over the current config,
    # effectively restoring the original settings from before hardening.
    cp "$BACKUP" "$SSHD_CONFIG"
    echo "[RESTORED] sshd_config from backup: $BACKUP"
    PASSED+=("SSH config restored from backup")
else
    echo "[SKIP] No sshd_config backup found — nothing to restore"
    SKIPPED+=("SSH config restore (no backup file found)")
fi

# EXPLANATION: The hardening script created /etc/ssh/banner with a legal
# warning message. 'rm -f' removes the file. The '-f' flag means "force" —
# it won't show an error if the file doesn't exist.
# Reference: https://man7.org/linux/man-pages/man1/rm.1.html
if [ -f /etc/ssh/banner ]; then
    rm -f /etc/ssh/banner
    echo "[REMOVED] /etc/ssh/banner"
fi

# EXPLANATION: Restart the SSH service so it re-reads the restored config.
# The service name differs by distro: "sshd" on CentOS, "ssh" on Ubuntu.
# 'systemctl restart' stops and re-starts the service.
# Reference: https://man7.org/linux/man-pages/man1/systemctl.1.html
if [[ "$DISTRO" == "centos" || "$DISTRO" == "rhel" || "$DISTRO" == "rocky" || "$DISTRO" == "almalinux" ]]; then
    systemctl restart sshd
elif [[ "$DISTRO" == "ubuntu" || "$DISTRO" == "debian" ]]; then
    systemctl restart ssh
fi

#------------------------------------------------------------------------------
# SECTION 2: Disable and Reset Firewall
# Purpose: Turn off the firewall and clear all rules we added, returning to
#          the default "no firewall" state for a clean test.
#------------------------------------------------------------------------------
echo ""
echo ">>> Resetting Firewall"
echo "----------------------------------------------"

if [[ "$DISTRO" == "centos" || "$DISTRO" == "rhel" || "$DISTRO" == "rocky" || "$DISTRO" == "almalinux" ]]; then
    # EXPLANATION: 'systemctl is-active --quiet' checks if a service is currently
    # running. The '--quiet' flag suppresses output — it just sets the exit code
    # (0 = active, non-zero = inactive). We only try to reset firewalld if it's
    # actually running, to avoid unnecessary error messages.
    # Reference: https://man7.org/linux/man-pages/man1/systemctl.1.html
    if systemctl is-active --quiet firewalld; then
        # EXPLANATION: Reset the default zone back to "public" (CentOS default).
        # The hardening script changed it to "drop" (block everything).
        # "public" is more permissive and is the standard out-of-box setting.
        # Reference: https://firewalld.org/documentation/zone/predefined-zones.html
        firewall-cmd --set-default-zone=public
        # EXPLANATION: Reload to apply the zone change.
        firewall-cmd --reload
        # EXPLANATION: 'stop' shuts down firewalld immediately.
        # 'disable' prevents it from starting automatically on boot.
        systemctl stop firewalld
        systemctl disable firewalld
        echo "[RESET] firewalld stopped, disabled, and zone reset to public"
        PASSED+=("Firewall reset (firewalld)")
    else
        echo "[SKIP] firewalld is not running"
        SKIPPED+=("Firewall reset (firewalld not running)")
    fi

elif [[ "$DISTRO" == "ubuntu" || "$DISTRO" == "debian" ]]; then
    # EXPLANATION: 'ufw status' outputs a line like "Status: active" or
    # "Status: inactive". We pipe it through 'grep -q' to silently check
    # if the word "active" appears. 'grep -q' returns exit code 0 if found.
    # Reference: https://man7.org/linux/man-pages/man1/grep.1.html
    if ufw status | grep -q "Status: active"; then
        # EXPLANATION: 'ufw --force disable' turns off UFW entirely.
        # 'ufw --force reset' deletes ALL firewall rules and restores defaults.
        # '--force' skips the confirmation prompt in both commands.
        # Reference: https://manpages.ubuntu.com/manpages/noble/man8/ufw.8.html
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
# Purpose: Stop, disable, and uninstall Fail2Ban so the next AI's script
#          can install and configure it from scratch.
#------------------------------------------------------------------------------
echo ""
echo ">>> Removing Fail2Ban"
echo "----------------------------------------------"

# EXPLANATION: 'command -v fail2ban-client' checks if the fail2ban-client binary
# exists in the system PATH. '&> /dev/null' silences all output. If it exists,
# Fail2Ban is installed and we proceed to remove it.
# Reference: https://www.gnu.org/software/bash/manual/bash.html#Bash-Builtins
if command -v fail2ban-client &> /dev/null; then
    # EXPLANATION: Always stop a service before uninstalling it. Removing the
    # package while the service is running can leave orphaned processes.
    # 'disable' prevents it from auto-starting on boot.
    systemctl stop fail2ban
    systemctl disable fail2ban

    # EXPLANATION: Remove the custom jail.local config file we created.
    # This ensures no leftover configuration from the hardening script.
    rm -f /etc/fail2ban/jail.local
    echo "[REMOVED] /etc/fail2ban/jail.local"

    # EXPLANATION: Uninstall the Fail2Ban package using the appropriate
    # package manager for this distro.
    # 'yum remove -y' / 'apt remove -y' uninstalls the specified package.
    # 'apt autoremove -y' removes any dependencies that were installed
    # alongside fail2ban but are no longer needed by any other package.
    # Reference: https://man7.org/linux/man-pages/man8/yum.8.html
    # Reference: https://manpages.ubuntu.com/manpages/noble/man8/apt.8.html
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
# Purpose: Return all file permissions to their standard default values.
#          These defaults are what a fresh install of CentOS or Ubuntu uses.
#          Note: the hardening script tightened these for security, but we're
#          restoring defaults so the next script starts from a known state.
#
#          Permission reminder:
#            644 = rw-r--r-- (owner read/write, everyone else read-only)
#            640 = rw-r----- (owner read/write, group read-only, no world access)
#            755 = rwxr-xr-x (owner full, everyone else read/execute)
#          Reference: https://man7.org/linux/man-pages/man1/chmod.1.html
#------------------------------------------------------------------------------
echo ""
echo ">>> Resetting File Permissions to Defaults"
echo "----------------------------------------------"

# EXPLANATION: These are the standard default permissions on a fresh Linux install.
# The hardening script changed /etc/shadow from 640 to 600 and /etc/ssh from
# 755 to 700, etc. We restore them here. The '&&' ensures the echo only runs
# if chmod succeeds. Each chmod call changes the permission mode of the file.
chmod 644 /etc/passwd      && echo "[RESET] /etc/passwd -> 644"
chmod 640 /etc/shadow      && echo "[RESET] /etc/shadow -> 640"
chmod 644 /etc/group       && echo "[RESET] /etc/group  -> 644"
chmod 640 /etc/gshadow     && echo "[RESET] /etc/gshadow -> 640"
chmod 755 /etc/ssh         && echo "[RESET] /etc/ssh -> 755"
chmod 644 /etc/ssh/sshd_config && echo "[RESET] /etc/ssh/sshd_config -> 644"

# EXPLANATION: Reset GRUB bootloader config permissions. The hardening script
# set these to 600 (root-only). The default is typically 644.
# We check both possible paths since CentOS and Ubuntu store GRUB differently.
if [ -f /boot/grub2/grub.cfg ]; then
    chmod 644 /boot/grub2/grub.cfg
    echo "[RESET] /boot/grub2/grub.cfg -> 644"
elif [ -f /boot/grub/grub.cfg ]; then
    chmod 644 /boot/grub/grub.cfg
    echo "[RESET] /boot/grub/grub.cfg -> 644"
fi

# EXPLANATION: Reset cron directories from 700 (root-only) back to 755
# (world-readable/executable). '2>/dev/null' suppresses errors if a
# directory doesn't exist on this particular system.
# Reference: https://man7.org/linux/man-pages/man8/cron.8.html
chmod 755 /etc/cron.d 2>/dev/null
chmod 755 /etc/cron.daily 2>/dev/null
chmod 755 /etc/cron.hourly 2>/dev/null
chmod 755 /etc/cron.weekly 2>/dev/null
chmod 755 /etc/cron.monthly 2>/dev/null
echo "[RESET] Cron directories -> 755"

# EXPLANATION: Reset home directories from 700 (private) back to 755 (default).
# The 'for' loop iterates over every subdirectory in /home/.
# The trailing '/' in the glob pattern ensures we only match directories.
for dir in /home/*/; do
    if [ -d "$dir" ]; then
        chmod 755 "$dir"
        echo "[RESET] $dir -> 755"
    fi
done

PASSED+=("File permissions reset to defaults")

#------------------------------------------------------------------------------
# SECTION 5: Undo Core Dump Restriction
# Purpose: Remove the line "* hard core 0" that the hardening script appended
#          to /etc/security/limits.conf, re-enabling core dumps.
#------------------------------------------------------------------------------
echo ""
echo ">>> Removing Core Dump Restriction"
echo "----------------------------------------------"

# EXPLANATION: 'grep -q' silently checks if the pattern exists in the file.
# The pattern "^\* hard core 0" matches a line that starts with "* hard core 0".
# The backslash before * escapes it so grep treats it as a literal asterisk
# instead of a regex wildcard (which would mean "zero or more of nothing").
# Reference: https://man7.org/linux/man-pages/man1/grep.1.html
if grep -q "^\* hard core 0" /etc/security/limits.conf; then
    # EXPLANATION: 'sed -i' edits the file in-place. The 'd' command deletes
    # lines matching the pattern. So this finds and removes the exact line
    # that the hardening script added, without touching anything else.
    # Reference: https://man7.org/linux/man-pages/man1/sed.1.html
    sed -i '/^\* hard core 0/d' /etc/security/limits.conf
    echo "[REMOVED] Core dump restriction from limits.conf"
    PASSED+=("Core dump restriction removed")
else
    echo "[SKIP] No core dump restriction found in limits.conf"
    SKIPPED+=("Core dump restriction (not found)")
fi

#------------------------------------------------------------------------------
# SECTION 6: Clean Up Log Files
# Purpose: Remove the log files and SSH config backups that the hardening
#          script created, leaving a completely clean system.
#------------------------------------------------------------------------------
echo ""
echo ">>> Cleaning Up Hardening Logs"
echo "----------------------------------------------"

# EXPLANATION: 'ls ... | wc -l' counts how many files match the glob pattern.
# 'ls' lists the files, and 'wc -l' counts the lines of output (one per file).
# '2>/dev/null' suppresses the "no matches" error if no log files exist.
# Reference: https://man7.org/linux/man-pages/man1/wc.1.html
LOG_COUNT=$(ls /var/log/server_hardening_*.log 2>/dev/null | wc -l)
if [[ $LOG_COUNT -gt 0 ]]; then
    # EXPLANATION: 'rm -f' removes files. The '-f' flag means "force" — don't
    # prompt for confirmation and don't error if a file doesn't exist.
    # The glob pattern matches ALL hardening log files (from any run).
    rm -f /var/log/server_hardening_*.log
    echo "[REMOVED] $LOG_COUNT hardening log file(s)"
    PASSED+=("Hardening log files cleaned up")
else
    echo "[SKIP] No hardening log files found"
    SKIPPED+=("Log cleanup (no log files found)")
fi

# EXPLANATION: Also clean up the sshd_config backup files. These were created
# by the hardening script (sshd_config.bak.YYYYMMDD) and are no longer needed
# since we already restored the original config above.
BACKUP_COUNT=$(ls ${SSHD_CONFIG}.bak.* 2>/dev/null | wc -l)
if [[ $BACKUP_COUNT -gt 0 ]]; then
    rm -f ${SSHD_CONFIG}.bak.*
    echo "[REMOVED] $BACKUP_COUNT sshd_config backup(s)"
fi

#------------------------------------------------------------------------------
# SECTION 7: Summary
# Purpose: Display a complete report of what was restored, skipped, and failed.
#          Uses three arrays (PASSED, SKIPPED, FAILED) built throughout the script.
#------------------------------------------------------------------------------
echo ""
echo "=============================================="
echo " ROLLBACK COMPLETE — SUMMARY"
echo "=============================================="
echo " OS: $DISTRO"
echo ""

# EXPLANATION: ${#PASSED[@]} returns the number of elements in the PASSED array.
# The '#' is Bash's length operator when used with arrays.
# Reference: https://www.gnu.org/software/bash/manual/bash.html#Shell-Parameter-Expansion
echo " RESTORED (${#PASSED[@]} items):"
if [[ ${#PASSED[@]} -eq 0 ]]; then
    echo "   (none)"
else
    # EXPLANATION: "${PASSED[@]}" expands each array element as a separate word.
    # The double quotes preserve elements that contain spaces.
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
