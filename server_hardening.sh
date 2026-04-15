#!/bin/bash
# EXPLANATION: This is called a "shebang" line. The #! tells the operating system
# that this file is a script, and /bin/bash says to use the Bash shell to run it.
# Without this line, the OS wouldn't know which interpreter to use.
# Reference: https://www.gnu.org/software/bash/manual/bash.html#Invoking-Bash

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

# EXPLANATION: $EUID is a built-in Bash variable that holds the "Effective User ID"
# of the current user. Root (the superuser/admin) always has UID 0.
# -ne means "not equal to". So this checks: "if the user is NOT root..."
# We need root because modifying system configs, installing packages, and
# changing file permissions all require superuser privileges.
# Reference: https://man7.org/linux/man-pages/man1/id.1.html
if [[ "$EUID" -ne 0 ]]; then
    # $0 is another built-in variable — it holds the name of the script itself.
    # This gives the user a helpful message showing exactly how to re-run it.
    echo "ERROR: This script must be run as root. Use: sudo bash $0"
    # EXPLANATION: 'exit 1' stops the script immediately. The number 1 is the
    # "exit code" — by convention, 0 means success and any non-zero number
    # means an error occurred. Other scripts or tools can check this code.
    # Reference: https://www.gnu.org/software/bash/manual/bash.html#Exit-Status
    exit 1
fi

# EXPLANATION: /etc/os-release is a standardized file on modern Linux systems
# that contains info about the distribution. The '-f' flag in the test checks
# if the file exists and is a regular file (not a directory or special file).
# Reference: https://www.freedesktop.org/software/systemd/man/os-release.html
if [ -f /etc/os-release ]; then
    # EXPLANATION: The '.' (dot) command is the same as 'source'. It reads the
    # file and executes it in the current shell, which loads variables like
    # $ID (distro name, e.g., "ubuntu" or "centos"), $VERSION_ID, etc.
    # into our environment so we can use them.
    # Reference: https://www.gnu.org/software/bash/manual/bash.html#Bourne-Shell-Builtins
    . /etc/os-release
    DISTRO=$ID
else
    echo "ERROR: Cannot detect OS. /etc/os-release not found."
    exit 1
fi

# EXPLANATION: 'echo' prints text to the terminal. We use it to display a header
# so the person running the script can see what's happening.
# $(date) is "command substitution" — it runs the 'date' command and inserts
# its output (the current date/time) into the string.
# Reference: https://www.gnu.org/software/bash/manual/bash.html#Command-Substitution
echo "=============================================="
echo " Server Hardening Script"
echo " Detected OS: $DISTRO"
echo " Date: $(date)"
echo "=============================================="

# EXPLANATION: We create a log file with a timestamp in the filename so each run
# gets its own unique log. The format string %Y%m%d_%H%M%S produces something
# like "20260415_143022" (year-month-day_hour-minute-second).
# Reference: https://man7.org/linux/man-pages/man1/date.1.html
LOGFILE="/var/log/server_hardening_$(date +%Y%m%d_%H%M%S).log"

# EXPLANATION: This is an advanced Bash redirect. Let's break it down:
# 'exec' without a command modifies the file descriptors for the current shell.
# '> >(tee -a "$LOGFILE")' redirects stdout (standard output) through 'tee'.
# 'tee -a' copies input to BOTH the terminal AND the log file (-a = append).
# '2>&1' redirects stderr (error output, file descriptor 2) to the same place
# as stdout (file descriptor 1), so errors also get logged.
# Result: everything printed by the script goes to both screen AND log file.
# Reference: https://www.gnu.org/software/bash/manual/bash.html#Redirections
# Reference: https://man7.org/linux/man-pages/man1/tee.1.html
exec > >(tee -a "$LOGFILE") 2>&1
echo "[INFO] Logging output to $LOGFILE"

# EXPLANATION: We declare two empty arrays using Bash array syntax.
# Arrays let us collect multiple values in a single variable.
# PASSED will hold the names of steps that succeeded.
# FAILED will hold the names of steps that failed.
# We'll loop through these at the end to print the summary.
# Reference: https://www.gnu.org/software/bash/manual/bash.html#Arrays
PASSED=()
FAILED=()

#------------------------------------------------------------------------------
# SECTION 1: System Updates
# Purpose: Ensure all packages are up to date to patch known vulnerabilities.
#          Outdated software is one of the most common attack vectors because
#          known vulnerabilities have published exploits that attackers can use.
#------------------------------------------------------------------------------
echo ""
echo ">>> SECTION 1: Applying System Updates"
echo "----------------------------------------------"

# EXPLANATION: We use '==' to compare strings in Bash. The '||' means "OR" —
# so this checks if $DISTRO matches any of these RHEL-family distributions.
# CentOS, RHEL, Rocky Linux, and AlmaLinux all use the same package manager.
if [[ "$DISTRO" == "centos" || "$DISTRO" == "rhel" || "$DISTRO" == "rocky" || "$DISTRO" == "almalinux" ]]; then
    # EXPLANATION: 'yum' is the Yellowdog Updater Modified — the default package
    # manager for RHEL-family distributions. 'yum update' downloads and installs
    # the latest versions of all installed packages. The '-y' flag automatically
    # answers "yes" to all confirmation prompts so the script can run unattended.
    # Reference: https://man7.org/linux/man-pages/man8/yum.8.html
    echo "[INFO] Updating packages with yum..."

    # EXPLANATION: '&&' chains two commands — the second only runs if the first
    # succeeds. 'epel-release' is the Extra Packages for Enterprise Linux repo,
    # which provides additional software (like Fail2Ban) not in the base repos.
    # The 'if' wrapping this checks the exit code: 0 = success, non-zero = fail.
    # Reference: https://docs.fedoraproject.org/en-US/epel/
    if yum update -y && yum install -y epel-release; then
        # EXPLANATION: '+=' appends a new element to the end of a Bash array.
        PASSED+=("System packages updated")
    else
        FAILED+=("System package updates (yum update failed)")
    fi
elif [[ "$DISTRO" == "ubuntu" || "$DISTRO" == "debian" ]]; then
    # EXPLANATION: 'apt' is the Advanced Package Tool — the package manager for
    # Debian-family distributions (Ubuntu, Debian, Linux Mint, etc.).
    # 'apt update' refreshes the list of available packages from the repositories
    # (it does NOT install anything — just updates the catalog).
    # 'apt upgrade' actually downloads and installs newer versions of packages.
    # Reference: https://manpages.ubuntu.com/manpages/noble/man8/apt.8.html
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
# Purpose: Enable a firewall and allow only necessary traffic (SSH on port 22).
#          A firewall filters network traffic — by default we block everything
#          incoming and then whitelist only the services we need. This is called
#          the "default deny" principle and is a core security best practice.
#------------------------------------------------------------------------------
echo ""
echo ">>> SECTION 2: Configuring Firewall"
echo "----------------------------------------------"

if [[ "$DISTRO" == "centos" || "$DISTRO" == "rhel" || "$DISTRO" == "rocky" || "$DISTRO" == "almalinux" ]]; then
    # EXPLANATION: firewalld is CentOS/RHEL's default firewall management daemon.
    # It provides a higher-level interface on top of iptables/nftables (the
    # kernel-level packet filtering frameworks). It uses "zones" to group rules.
    # Reference: https://firewalld.org/documentation/
    echo "[INFO] Setting up firewalld..."
    
    # EXPLANATION: 'yum install -y firewalld' installs the firewalld package.
    # On a fresh CentOS install it's usually already there, but this ensures
    # it's present even if someone removed it.
    yum install -y firewalld
    
    # EXPLANATION: 'systemctl' is the command for managing systemd services.
    # 'start' launches the service immediately.
    # 'enable' configures it to start automatically at boot.
    # These are separate actions — start affects NOW, enable affects FUTURE boots.
    # Reference: https://man7.org/linux/man-pages/man1/systemctl.1.html
    systemctl start firewalld
    systemctl enable firewalld
    
    # EXPLANATION: firewalld organizes rules into "zones". The "drop" zone is the
    # most restrictive — it silently drops all incoming connections that aren't
    # explicitly allowed (doesn't even send back a "connection refused" message).
    # '--set-default-zone=drop' makes this the default for all network interfaces.
    # Other zones include: public, home, trusted, dmz, etc.
    # Reference: https://firewalld.org/documentation/zone/predefined-zones.html
    firewall-cmd --set-default-zone=drop
    
    # EXPLANATION: 'firewall-cmd' is the command-line client for firewalld.
    # '--zone=drop' specifies which zone to modify.
    # '--add-service=ssh' allows SSH traffic (port 22/tcp) through the firewall.
    # '--permanent' saves the rule so it persists after reboot. Without this flag,
    # the rule would only last until the next firewalld restart.
    # Reference: https://firewalld.org/documentation/man-pages/firewall-cmd.html
    firewall-cmd --zone=drop --add-service=ssh --permanent
    
    # EXPLANATION: HTTP (port 80) and HTTPS (port 443) are web server ports.
    # We allow these in case this server hosts a website. If it doesn't,
    # these lines should be removed to minimize the attack surface.
    firewall-cmd --zone=drop --add-service=http --permanent
    firewall-cmd --zone=drop --add-service=https --permanent
    
    # EXPLANATION: '--reload' re-reads all permanent rules and applies them.
    # Permanent rules don't take effect until you reload or restart firewalld.
    if firewall-cmd --reload; then
        PASSED+=("Firewall configured (firewalld)")
    else
        FAILED+=("Firewall configuration (firewalld reload failed)")
    fi
    
    # EXPLANATION: '--list-all' displays every rule in the current default zone,
    # so we can visually verify that only the services we want are allowed.
    echo "[INFO] Current firewall rules:"
    firewall-cmd --list-all

elif [[ "$DISTRO" == "ubuntu" || "$DISTRO" == "debian" ]]; then
    # EXPLANATION: UFW (Uncomplicated Firewall) is Ubuntu's user-friendly
    # frontend for iptables/nftables. It simplifies rule management compared
    # to writing raw iptables rules.
    # Reference: https://help.ubuntu.com/community/UFW
    echo "[INFO] Setting up UFW..."
    
    apt install -y ufw
    
    # EXPLANATION: 'ufw default deny incoming' sets the default policy for all
    # incoming connections to DENY (block). This means unless we explicitly
    # create an "allow" rule for a service, it will be blocked.
    # 'ufw default allow outgoing' lets the server make outbound connections
    # (e.g., to download updates, send emails, make API calls).
    # Reference: https://manpages.ubuntu.com/manpages/noble/man8/ufw.8.html
    ufw default deny incoming
    ufw default allow outgoing
    
    # EXPLANATION: 'ufw allow ssh' creates a rule allowing inbound connections
    # on port 22/tcp (the SSH port). UFW knows that "ssh" = port 22 because
    # it reads from /etc/services which maps service names to port numbers.
    # This is CRITICAL — without this rule, enabling UFW would lock you out
    # of a remote server since you couldn't SSH back in.
    ufw allow ssh
    
    # EXPLANATION: Same concept — allow web traffic. 'http' = port 80,
    # 'https' = port 443. Remove these if the server doesn't host a website.
    ufw allow http
    ufw allow https
    
    # EXPLANATION: 'ufw --force enable' activates the firewall. The '--force'
    # flag skips the interactive "are you sure?" prompt, which is necessary
    # for scripts since there's no human to type "y".
    if ufw --force enable; then
        PASSED+=("Firewall configured (UFW)")
    else
        FAILED+=("Firewall configuration (UFW enable failed)")
    fi
    
    # EXPLANATION: 'ufw status verbose' shows all active rules plus the default
    # policies in detail, so we can verify the configuration is correct.
    echo "[INFO] Current UFW status:"
    ufw status verbose
fi

echo "[DONE] Firewall configuration complete."

#------------------------------------------------------------------------------
# SECTION 3: SSH Hardening
# Purpose: Secure the SSH (Secure Shell) service to prevent unauthorized access.
#          SSH is the primary way admins connect to remote servers, so it's one
#          of the most targeted services by attackers. Hardening it reduces the
#          attack surface significantly.
#------------------------------------------------------------------------------
echo ""
echo ">>> SECTION 3: Hardening SSH Configuration"
echo "----------------------------------------------"

# EXPLANATION: sshd_config is the configuration file for the SSH daemon (server).
# "sshd" = SSH Daemon — the background process that listens for SSH connections.
# All SSH server behavior is controlled by settings in this file.
# Reference: https://man7.org/linux/man-pages/man5/sshd_config.5.html
SSHD_CONFIG="/etc/ssh/sshd_config"

# EXPLANATION: Before modifying any config file, we make a backup copy.
# 'cp' copies the file, and we append today's date to the backup filename
# (e.g., sshd_config.bak.20260415) so we can restore it if something breaks.
# This is a critical safety practice — always back up before editing configs.
cp "$SSHD_CONFIG" "${SSHD_CONFIG}.bak.$(date +%Y%m%d)"
echo "[INFO] Backed up sshd_config to ${SSHD_CONFIG}.bak.$(date +%Y%m%d)"

# EXPLANATION: This is a Bash function — a reusable block of code we can call
# by name. We define it once and call it for each SSH setting we want to change.
# 'local' declares variables that only exist inside this function.
# The function takes two arguments: $1 = the setting name, $2 = the new value.
set_sshd_option() {
    local key="$1"
    local value="$2"
    # EXPLANATION: 'grep -qE' searches the file using Extended Regular Expressions.
    # -q = quiet mode (don't print matches, just set exit code).
    # -E = use extended regex syntax.
    # The regex "^\s*#?\s*${key}\b" matches lines that:
    #   ^ = start of line
    #   \s* = optional whitespace
    #   #? = optional comment character (so it finds commented-out settings too)
    #   \s* = optional whitespace after the #
    #   ${key}\b = the setting name followed by a word boundary
    # Reference: https://man7.org/linux/man-pages/man1/grep.1.html
    if grep -qE "^\s*#?\s*${key}\b" "$SSHD_CONFIG"; then
        # EXPLANATION: 'sed -i' edits the file in-place.
        # The 's/pattern/replacement/' syntax replaces matching text.
        # This replaces the entire line (whether commented or not) with the
        # new key-value pair, effectively uncommenting and updating it.
        # Reference: https://man7.org/linux/man-pages/man1/sed.1.html
        sed -i "s/^\s*#*\s*${key}\b.*/${key} ${value}/" "$SSHD_CONFIG"
    else
        # EXPLANATION: '>>' appends text to the end of a file (vs '>' which
        # would overwrite the entire file). If the setting doesn't exist at all
        # in the config file, we add it as a new line at the bottom.
        echo "${key} ${value}" >> "$SSHD_CONFIG"
    fi
    echo "[SET] ${key} = ${value}"
}

# --- SSH Hardening Settings ---

# EXPLANATION: PermitRootLogin controls whether the root account can log in via SSH.
# Setting it to "no" forces attackers to guess both a username AND a password,
# instead of just needing to brute-force the password for the known "root" account.
# Users should log in with their own accounts and use 'sudo' for admin tasks.
# Reference: https://man7.org/linux/man-pages/man5/sshd_config.5.html
set_sshd_option "PermitRootLogin" "no"

# EXPLANATION: SSH has two protocol versions. Protocol 1 is obsolete and has
# known cryptographic weaknesses (e.g., vulnerable to session hijacking).
# Protocol 2 uses stronger encryption and is the modern standard.
# Note: On newer SSH versions (7.4+), Protocol 1 has been removed entirely,
# so this line may produce a warning but is kept for older systems.
# Reference: https://www.openssh.com/releasenotes.html
set_sshd_option "Protocol" "2"

# EXPLANATION: MaxAuthTries limits how many authentication attempts a user gets
# per connection before being disconnected. Setting it to 3 means after 3
# wrong passwords, SSH drops the connection. This slows down brute-force
# attacks where attackers try thousands of passwords automatically.
# Reference: https://man7.org/linux/man-pages/man5/sshd_config.5.html
set_sshd_option "MaxAuthTries" "3"

# EXPLANATION: PasswordAuthentication controls whether users can log in with
# a password. SSH key-based auth is far more secure because:
# - SSH keys use 2048+ bit encryption (vs ~40 bits of entropy in a password)
# - Keys can't be brute-forced over the network
# - Keys can be protected with a passphrase for two-factor security
# We keep this as "yes" for the lab so you don't get locked out. In production,
# you'd set up SSH keys first, then change this to "no".
# Reference: https://man7.org/linux/man-pages/man5/sshd_config.5.html
set_sshd_option "PasswordAuthentication" "yes"

# EXPLANATION: PermitEmptyPasswords prevents accounts that have no password set
# from logging in via SSH. This is a safety net — if someone creates a user
# account and forgets to set a password, attackers can't exploit that mistake.
# Reference: https://man7.org/linux/man-pages/man5/sshd_config.5.html
set_sshd_option "PermitEmptyPasswords" "no"

# EXPLANATION: ClientAliveInterval is the number of seconds the server waits
# before sending a keepalive message to the client. 300 = 5 minutes.
# ClientAliveCountMax is how many keepalive messages can go unanswered before
# the server disconnects the client. Setting it to 0 means: after 5 minutes
# of no response, disconnect immediately. This prevents "zombie sessions" —
# SSH connections that stay open after someone walks away, which an attacker
# could hijack if they gain physical access to the terminal.
# Reference: https://man7.org/linux/man-pages/man5/sshd_config.5.html
set_sshd_option "ClientAliveInterval" "300"
set_sshd_option "ClientAliveCountMax" "0"

# EXPLANATION: X11Forwarding allows graphical applications on the server to
# display their windows on the client's screen. This is rarely needed on
# servers (which typically have no GUI) and introduces security risks because
# it opens an additional communication channel that could be exploited.
# The X11 protocol itself has known security weaknesses.
# Reference: https://man7.org/linux/man-pages/man5/sshd_config.5.html
set_sshd_option "X11Forwarding" "no"

# EXPLANATION: LoginGraceTime is the number of seconds a user has to complete
# authentication after connecting. If they don't log in within 60 seconds,
# the server drops the connection. This prevents attackers from opening many
# connections and leaving them hanging to consume server resources (a type
# of denial-of-service attack).
# Reference: https://man7.org/linux/man-pages/man5/sshd_config.5.html
set_sshd_option "LoginGraceTime" "60"

# EXPLANATION: 'cat > file << EOF' is called a "here document" (heredoc).
# It writes everything between << 'EOF' and the closing EOF into the file.
# The single quotes around 'EOF' prevent variable expansion — the text is
# written exactly as-is. We're creating a legal warning banner that displays
# before login. This banner serves as a legal deterrent and may be required
# for compliance in many organizations (e.g., NIST 800-53 requires it).
# Reference: https://www.gnu.org/software/bash/manual/bash.html#Here-Documents
cat > /etc/ssh/banner << 'EOF'
*******************************************************************
*  WARNING: This system is for authorized users only.             *
*  All activity is monitored and logged.                          *
*  Unauthorized access is prohibited and will be prosecuted.      *
*******************************************************************
EOF

# EXPLANATION: The Banner directive tells sshd to display the contents of
# the specified file to users BEFORE they authenticate. This is the first
# thing anyone connecting via SSH will see.
# Reference: https://man7.org/linux/man-pages/man5/sshd_config.5.html
set_sshd_option "Banner" "/etc/ssh/banner"

# EXPLANATION: After changing sshd_config, we must restart the SSH service
# for the changes to take effect. The service name differs by distro:
# CentOS/RHEL uses "sshd", Ubuntu/Debian uses "ssh".
# 'systemctl restart' stops and then starts the service.
# IMPORTANT: If the config has syntax errors, the restart will fail and
# SSH will go down — which is why we made a backup first.
# Reference: https://man7.org/linux/man-pages/man1/systemctl.1.html
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
# Purpose: Restrict access to sensitive system files and directories.
#          Linux file permissions use a 3-digit octal number (e.g., 644):
#            - First digit: owner permissions
#            - Second digit: group permissions
#            - Third digit: everyone else (world) permissions
#          Each digit is a sum of: 4=read, 2=write, 1=execute
#          So 644 = owner:rw(6), group:r(4), world:r(4) = rw-r--r--
#          And 700 = owner:rwx(7), group:none(0), world:none(0) = rwx------
#          Reference: https://man7.org/linux/man-pages/man1/chmod.1.html
#------------------------------------------------------------------------------
echo ""
echo ">>> SECTION 4: Hardening File Permissions"
echo "----------------------------------------------"

# EXPLANATION: /etc/passwd contains one line per user account with fields like
# username, UID, GID, home directory, and login shell. Despite the name, it
# does NOT contain passwords (those moved to /etc/shadow long ago). It needs
# to be world-readable (644) because many programs need to look up usernames.
# Reference: https://man7.org/linux/man-pages/man5/passwd.5.html
if chmod 644 /etc/passwd; then
    echo "[SET] /etc/passwd permissions to 644 (rw-r--r--)"
else
    echo "[FAIL] Could not set /etc/passwd permissions"
    FAILED+=("File permissions: /etc/passwd")
fi

# EXPLANATION: /etc/shadow contains the actual hashed passwords for each user.
# It must be locked down to 600 (root-only read/write) because if an attacker
# can read this file, they can run offline password-cracking tools like
# John the Ripper or hashcat against the hashes.
# Reference: https://man7.org/linux/man-pages/man5/shadow.5.html
if chmod 600 /etc/shadow; then
    echo "[SET] /etc/shadow permissions to 600 (rw-------)"
else
    echo "[FAIL] Could not set /etc/shadow permissions"
    FAILED+=("File permissions: /etc/shadow")
fi

# EXPLANATION: /etc/group lists all groups on the system and their members.
# Like /etc/passwd, many programs need to read this to resolve group names,
# so it stays world-readable (644).
# Reference: https://man7.org/linux/man-pages/man5/group.5.html
if chmod 644 /etc/group; then
    echo "[SET] /etc/group permissions to 644 (rw-r--r--)"
else
    echo "[FAIL] Could not set /etc/group permissions"
    FAILED+=("File permissions: /etc/group")
fi

# EXPLANATION: /etc/gshadow is the shadow file for groups — it stores encrypted
# group passwords and group admin info. Like /etc/shadow, it should be
# restricted to root only (600).
# Reference: https://man7.org/linux/man-pages/man5/gshadow.5.html
if chmod 600 /etc/gshadow; then
    echo "[SET] /etc/gshadow permissions to 600 (rw-------)"
else
    echo "[FAIL] Could not set /etc/gshadow permissions"
    FAILED+=("File permissions: /etc/gshadow")
fi

# EXPLANATION: /etc/ssh/ is the directory containing all SSH server configuration,
# including host keys (the server's identity). If an attacker can read the host
# keys, they can impersonate the server (man-in-the-middle attack). Setting to
# 700 means only root can enter or list the directory.
# Reference: https://man7.org/linux/man-pages/man5/sshd_config.5.html
if chmod 700 /etc/ssh; then
    echo "[SET] /etc/ssh permissions to 700 (rwx------)"
else
    echo "[FAIL] Could not set /etc/ssh permissions"
    FAILED+=("File permissions: /etc/ssh")
fi

# EXPLANATION: /etc/ssh/sshd_config contains the SSH server settings we just
# modified. If a non-root user could read this, they'd learn the server's
# security configuration (which settings are enabled/disabled), which helps
# attackers plan their approach. 600 = root read/write only.
if chmod 600 /etc/ssh/sshd_config; then
    echo "[SET] /etc/ssh/sshd_config permissions to 600 (rw-------)"
else
    echo "[FAIL] Could not set /etc/ssh/sshd_config permissions"
    FAILED+=("File permissions: /etc/ssh/sshd_config")
fi

# EXPLANATION: This loop counts how many file permission failures occurred above.
# We check the FAILED array for entries starting with "File permissions".
# If none failed, we record the whole section as passed.
FILE_PERM_FAILURES=0
for item in "${FAILED[@]}"; do
    # EXPLANATION: '==' with a pattern (File\ permissions*) does glob matching.
    # The backslash escapes the space. The * matches anything after "permissions".
    if [[ "$item" == File\ permissions* ]]; then
        # EXPLANATION: '((...))' is arithmetic evaluation in Bash.
        # ++ is the increment operator (adds 1 to the variable).
        ((FILE_PERM_FAILURES++))
    fi
done
if [[ $FILE_PERM_FAILURES -eq 0 ]]; then
    PASSED+=("Sensitive file permissions tightened")
fi

# EXPLANATION: GRUB is the bootloader — the program that loads Linux when the
# computer starts. If an attacker can modify grub.cfg, they could boot into
# single-user mode (which gives root access without a password) or load a
# malicious kernel. The path differs: CentOS uses /boot/grub2/, Ubuntu uses
# /boot/grub/. We check which exists and lock it down.
# Reference: https://www.gnu.org/software/grub/manual/grub/grub.html
if [ -f /boot/grub2/grub.cfg ]; then
    chmod 600 /boot/grub2/grub.cfg
    echo "[SET] /boot/grub2/grub.cfg permissions to 600"
elif [ -f /boot/grub/grub.cfg ]; then
    chmod 600 /boot/grub/grub.cfg
    echo "[SET] /boot/grub/grub.cfg permissions to 600"
fi

# EXPLANATION: Cron is the Linux task scheduler — it runs commands at specified
# times (like Windows Task Scheduler). The /etc/cron.* directories hold scripts
# that run daily, hourly, weekly, or monthly. If an attacker can add a script
# to these directories, it will run automatically as root. Setting to 700
# means only root can view or modify scheduled tasks.
# '2>/dev/null' redirects error messages to /dev/null (discards them) in case
# a cron directory doesn't exist on this system.
# Reference: https://man7.org/linux/man-pages/man8/cron.8.html
chmod 700 /etc/cron.d 2>/dev/null
chmod 700 /etc/cron.daily 2>/dev/null
chmod 700 /etc/cron.hourly 2>/dev/null
chmod 700 /etc/cron.weekly 2>/dev/null
chmod 700 /etc/cron.monthly 2>/dev/null
echo "[SET] Cron directories permissions to 700 (rwx------)"

echo "[DONE] File permission hardening complete."

#------------------------------------------------------------------------------
# SECTION 5: Additional Security Measures
# Purpose: Install intrusion prevention tools and apply extra hardening
#------------------------------------------------------------------------------
echo ""
echo ">>> SECTION 5: Additional Security Measures"
echo "----------------------------------------------"

# EXPLANATION: Fail2Ban is an intrusion prevention tool that monitors log files
# (like /var/log/auth.log) for failed login attempts. When it detects too many
# failures from a single IP address, it automatically creates a firewall rule
# to block (ban) that IP for a set period. This is extremely effective against
# automated brute-force attacks.
# Reference: https://www.fail2ban.org/wiki/index.php/Main_Page
echo "[INFO] Installing Fail2Ban..."
if [[ "$DISTRO" == "centos" || "$DISTRO" == "rhel" || "$DISTRO" == "rocky" || "$DISTRO" == "almalinux" ]]; then
    yum install -y fail2ban
elif [[ "$DISTRO" == "ubuntu" || "$DISTRO" == "debian" ]]; then
    apt install -y fail2ban
fi

# EXPLANATION: 'command -v' checks if a command exists in the system's PATH.
# '&> /dev/null' redirects both stdout and stderr to /dev/null (silences output).
# The '!' negates the test — so this says "if fail2ban-client does NOT exist".
# This is a more reliable check than looking at the install command's exit code,
# because it verifies the binary is actually available.
# Reference: https://www.gnu.org/software/bash/manual/bash.html#Bash-Builtins
if ! command -v fail2ban-client &> /dev/null; then
    echo "[FAIL] Fail2Ban installation failed"
    FAILED+=("Fail2Ban installation")
else

# EXPLANATION: jail.local is Fail2Ban's local override file. Fail2Ban reads
# jail.conf first (the defaults), then jail.local overrides specific settings.
# We use jail.local instead of editing jail.conf so our settings survive updates.
# The [DEFAULT] section sets global defaults:
#   bantime = 3600: block the attacker's IP for 1 hour (3600 seconds)
#   findtime = 600: look at the last 10 minutes of logs for failures
#   maxretry = 5: ban after 5 failed attempts within findtime
# The [sshd] section enables monitoring of the SSH service specifically.
#   logpath = %(sshd_log)s: auto-detects the SSH log path for this distro
#   backend = %(sshd_backend)s: auto-detects the log monitoring backend
# Reference: https://www.fail2ban.org/wiki/index.php/MANUAL_0_8#Jails
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

# EXPLANATION: 'systemctl start' launches Fail2Ban immediately.
# 'systemctl enable' ensures it starts automatically on every boot.
# The '&&' ensures enable only runs if start succeeds.
    if systemctl start fail2ban && systemctl enable fail2ban; then
        PASSED+=("Fail2Ban installed and configured")
    else
        FAILED+=("Fail2Ban service start (installed but failed to start)")
    fi
    echo "[DONE] Fail2Ban installed and configured."
fi

# EXPLANATION: A "core dump" is a file the OS creates when a program crashes,
# containing the program's memory contents at the time of the crash. This can
# include sensitive data like passwords, encryption keys, or session tokens.
# /etc/security/limits.conf controls resource limits for users.
# '* hard core 0' means: for ALL users (*), set a HARD limit (can't be raised)
# on core dump file size to 0 (effectively disabling them).
# Reference: https://man7.org/linux/man-pages/man5/limits.conf.5.html
if echo "* hard core 0" >> /etc/security/limits.conf; then
    PASSED+=("Core dumps disabled")
    echo "[SET] Core dumps disabled via limits.conf"
else
    FAILED+=("Core dumps (could not write to limits.conf)")
    echo "[FAIL] Could not disable core dumps"
fi

# EXPLANATION: By default, home directories on some Linux distros are created
# with permissions like 755 (world-readable), meaning any user on the system
# can browse other users' files. Setting to 700 makes each home directory
# private — only the owner can access it. The 'for' loop iterates over every
# directory in /home/ that matches the glob pattern /home/*/ .
# Reference: https://man7.org/linux/man-pages/man1/chmod.1.html
echo "[INFO] Securing home directory permissions..."
HOME_DIR_FAIL=0
for dir in /home/*/; do
    # EXPLANATION: '-d' tests if the path is a directory (not a file or symlink).
    # Reference: https://www.gnu.org/software/bash/manual/bash.html#Bash-Conditional-Expressions
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
# Purpose: Display what passed and what failed for documentation.
#          This uses the PASSED and FAILED arrays we built throughout the script.
#------------------------------------------------------------------------------
echo ""
echo "=============================================="
echo " HARDENING COMPLETE — SUMMARY"
echo "=============================================="
echo " OS Detected:            $DISTRO"
echo " Log File:               $LOGFILE"
echo " SSH Config Backup:      ${SSHD_CONFIG}.bak.$(date +%Y%m%d)"
echo ""

# EXPLANATION: ${#PASSED[@]} gets the LENGTH (number of elements) of the array.
# The # before the variable name is Bash's "length" operator for arrays.
# Reference: https://www.gnu.org/software/bash/manual/bash.html#Shell-Parameter-Expansion
echo " PASSED (${#PASSED[@]} items):"
if [[ ${#PASSED[@]} -eq 0 ]]; then
    echo "   (none)"
else
    # EXPLANATION: This 'for' loop iterates over every element in the PASSED array.
    # "${PASSED[@]}" expands to all elements, each properly quoted.
    for item in "${PASSED[@]}"; do
        echo "   [✓] $item"
    done
fi

echo ""

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

if [[ ${#FAILED[@]} -gt 0 ]]; then
    echo ""
    echo " ⚠ SOME STEPS FAILED — review the log file for details:"
    echo "   cat $LOGFILE"
fi

echo "=============================================="
