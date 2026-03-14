#!/bin/bash
 
# Darwin Marmolejos
# CIS-245-O1A
# March 14, 2026
 
# This script provides interactive network troubleshooting suggestions
# based on which server type you're running (Ubuntu or CentOS).
# It uses a menu system with read/case for user interaction.
 
# Run from any directory: bash troubleshooter.sh
# No special permissions needed, but some suggestions include sudo commands.
 
# ---- Helper Functions ----
 
# Prints a section divider to keep the output clean
divider() {
    echo ""
    echo "=============================================="
    echo ""
}
 
# Pauses and waits for the user to press Enter before continuing
pause() {
    echo ""
    read -p "Press Enter to return to the menu..."
}
 
# Server Selection
 
echo "=============================================="
echo "  NETWORK TROUBLESHOOTING TOOL"
echo "  Darwin Marmolejos "
echo "=============================================="
echo ""
echo "Which server are you troubleshooting?"
echo ""
echo "  1) Ubuntu"
echo "  2) CentOS"
echo ""
read -p "Enter your choice (1 or 2): " SERVER
 
# Validate the input
case $SERVER in
    1)
        OS="Ubuntu"
        echo ""
        echo "You selected Ubuntu. Loading troubleshooting options..."
        ;;
    2)
        OS="CentOS"
        echo ""
        echo "You selected CentOS. Loading troubleshooting options..."
        ;;
    *)
        echo "Invalid choice. Please run the script again and select 1 or 2."
        exit 1
        ;;
esac
 
# Main Menu Loop
 
# The while loop keeps the menu running until the user chooses to exit.
# This way they can run multiple troubleshooting steps without restarting.
 
RUNNING=true
while $RUNNING; do
    divider
    echo "  TROUBLESHOOTING MENU ($OS)"
    divider
    echo "  1) Fix no internet connectivity"
    echo "  2) Set a static IP address"
    echo "  3) Check and change DNS settings"
    echo "  4) Run a traceroute to google.com"
    echo "  5) Check network interface status"
    echo "  6) Check firewall rules"
    echo "  7) Restart networking service"
    echo "  8) Exit"
    echo ""
    read -p "Select an option (1-8): " CHOICE
 
    case $CHOICE in
 
        # ---- Option 1: No Internet Connectivity ----
        1)
            divider
            echo "  TROUBLESHOOTING: No Internet Connectivity ($OS)"
            divider
            echo "Step 1: Check if your network interface is up"
            echo "  Run: ip link show"
            echo "  Look for 'state UP' next to your interface (enp0s5, eth0, etc.)"
            echo "  If it says DOWN, bring it up with:"
            if [ "$OS" = "Ubuntu" ]; then
                echo "    sudo ip link set enp0s5 up"
            else
                echo "    sudo nmcli con up <connection-name>"
                echo "    (find your connection name with: nmcli con show)"
            fi
            echo ""
            echo "Step 2: Check if you have an IP address"
            echo "  Run: ip a"
            echo "  Look for an inet address on your main interface."
            echo "  If there's no IP, your DHCP might not be working."
            if [ "$OS" = "Ubuntu" ]; then
                echo "  Try: sudo dhclient enp0s5"
                echo "  Or restart netplan: sudo netplan apply"
            else
                echo "  Try: sudo nmcli con up <connection-name>"
                echo "  Or restart NetworkManager: sudo systemctl restart NetworkManager"
            fi
            echo ""
            echo "Step 3: Check if you can reach the gateway"
            echo "  Run: ip r"
            echo "  Find the default gateway IP, then ping it:"
            echo "    ping -c 3 <gateway-ip>"
            echo "  If this fails, the problem is between you and the router."
            echo ""
            echo "Step 4: Check if you can reach the internet"
            echo "  Run: ping -c 3 8.8.8.8"
            echo "  If this works but websites don't load, it's a DNS issue (see option 3)."
            echo "  If this fails, the problem is beyond your local network."
            echo ""
            echo "Step 5: Check DNS resolution"
            echo "  Run: ping -c 3 google.com"
            echo "  If this fails but pinging 8.8.8.8 works, your DNS is broken."
            echo "  See option 3 for DNS troubleshooting."
            pause
            ;;
 
        # Option 2: Set a Static IP
        2)
            divider
            echo "  SET A STATIC IP ADDRESS ($OS)"
            divider
            if [ "$OS" = "Ubuntu" ]; then
                echo "On Ubuntu, static IPs are set through Netplan config files."
                echo ""
                echo "Step 1: Find your current config file"
                echo "  Run: ls /etc/netplan/"
                echo "  You'll see a .yaml file (like 50-cloud-init.yaml)"
                echo ""
                echo "Step 2: Edit the config file"
                echo "  Run: sudo nano /etc/netplan/50-cloud-init.yaml"
                echo ""
                echo "Step 3: Replace the contents with a static config like this:"
                echo "  network:"
                echo "    version: 2"
                echo "    ethernets:"
                echo "      enp0s5:"
                echo "        dhcp4: no"
                echo "        addresses:"
                echo "          - 192.168.1.100/24"
                echo "        gateway4: 192.168.1.1"
                echo "        nameservers:"
                echo "          addresses: [8.8.8.8, 8.8.4.4]"
                echo ""
                echo "Step 4: Apply the changes"
                echo "  Run: sudo netplan apply"
                echo "  Or test first with: sudo netplan try (auto-reverts in 120 seconds)"
                echo ""
                echo "Step 5: Verify"
                echo "  Run: ip a"
                echo "  You should see your new static IP on the interface."
            else
                echo "On CentOS 10, static IPs are set through nmcli commands."
                echo ""
                echo "Step 1: Find your connection name"
                echo "  Run: nmcli connection show"
                echo "  Note the NAME of the active connection."
                echo ""
                echo "Step 2: Set the static IP"
                echo "  Run these commands (replace <name> with your connection name):"
                echo "    sudo nmcli con mod <name> ipv4.method manual"
                echo "    sudo nmcli con mod <name> ipv4.addresses 192.168.1.101/24"
                echo "    sudo nmcli con mod <name> ipv4.gateway 192.168.1.1"
                echo "    sudo nmcli con mod <name> ipv4.dns \"8.8.8.8 8.8.4.4\""
                echo ""
                echo "Step 3: Apply the changes"
                echo "  Run: sudo nmcli con up <name>"
                echo ""
                echo "Step 4: Verify"
                echo "  Run: ip a"
                echo "  You should see your new static IP on the interface."
            fi
            pause
            ;;
 
        # Option 3: DNS Troubleshooting
        3)
            divider
            echo "  CHECK AND CHANGE DNS SETTINGS ($OS)"
            divider
            echo "Step 1: Check current DNS servers"
            if [ "$OS" = "Ubuntu" ]; then
                echo "  Run: resolvectl status"
                echo "  This shows the DNS servers per interface."
                echo "  Or check: cat /etc/resolv.conf"
                echo "  (On Ubuntu this usually points to 127.0.0.53, the local stub resolver)"
            else
                echo "  Run: nmcli device show | grep DNS"
                echo "  This shows which DNS servers NetworkManager is using."
                echo "  Or check: cat /etc/resolv.conf"
            fi
            echo ""
            echo "Step 2: Test DNS resolution"
            echo "  Run: nslookup google.com"
            echo "  If this fails, your DNS servers might be unreachable or misconfigured."
            echo ""
            echo "Step 3: Change DNS servers"
            if [ "$OS" = "Ubuntu" ]; then
                echo "  Edit your Netplan config: sudo nano /etc/netplan/50-cloud-init.yaml"
                echo "  Add or change the nameservers section:"
                echo "    nameservers:"
                echo "      addresses: [8.8.8.8, 8.8.4.4]"
                echo "  Then apply: sudo netplan apply"
            else
                echo "  Run: sudo nmcli con mod <name> ipv4.dns \"8.8.8.8 8.8.4.4\""
                echo "  Then apply: sudo nmcli con up <name>"
            fi
            echo ""
            echo "Common public DNS servers to try:"
            echo "  Google:     8.8.8.8 and 8.8.4.4"
            pause
            ;;
 
        # Option 4: Traceroute
        4)
            divider
            echo "  RUNNING TRACEROUTE TO google.com ($OS)"
            divider
            echo "Traceroute shows every router (hop) between your server and the"
            echo "destination. If there's a problem at a specific hop, this helps"
            echo "you identify exactly where the issue is."
            echo ""
            if command -v traceroute &> /dev/null; then
                echo "Running: traceroute -m 15 google.com"
                echo "(Limited to 15 hops max)"
                echo ""
                traceroute -m 15 google.com
            else
                echo "traceroute is not installed. Install it with:"
                if [ "$OS" = "Ubuntu" ]; then
                    echo "  sudo apt install traceroute"
                else
                    echo "  sudo dnf install traceroute"
                fi
            fi
            pause
            ;;
 
        # Option 5: Check Interface Status
        5)
            divider
            echo "  NETWORK INTERFACE STATUS ($OS)"
            divider
            echo "Running: ip -br a"
            echo "(Brief view of all interfaces and their IPs)"
            echo ""
            ip -br a
            echo ""
            echo "Running: ip link show"
            echo "(Detailed interface status)"
            echo ""
            ip link show
            if [ "$OS" = "CentOS" ]; then
                echo ""
                echo "Running: nmcli device status"
                echo "(NetworkManager device overview)"
                echo ""
                nmcli device status
            fi
            pause
            ;;
 
        # Option 6: Firewall Rules
        6)
            divider
            echo "  FIREWALL STATUS ($OS)"
            divider
            if [ "$OS" = "Ubuntu" ]; then
                echo "Ubuntu uses ufw (Uncomplicated Firewall) by default."
                echo ""
                echo "Running: sudo ufw status verbose"
                echo ""
                sudo ufw status verbose
                echo ""
                echo "If ufw is inactive and you want to enable it:"
                echo "  sudo ufw enable"
                echo "To allow a specific port (like SSH on 22):"
                echo "  sudo ufw allow 22"
            else
                echo "CentOS uses firewalld by default."
                echo ""
                echo "Running: sudo firewall-cmd --list-all"
                echo ""
                sudo firewall-cmd --list-all
                echo ""
                echo "To open a specific port (like 80 for HTTP):"
                echo "  sudo firewall-cmd --add-port=80/tcp --permanent"
                echo "  sudo firewall-cmd --reload"
            fi
            pause
            ;;
 
        # Option 7: Restart Networking
        7)
            divider
            echo "  RESTART NETWORKING SERVICE ($OS)"
            divider
            if [ "$OS" = "Ubuntu" ]; then
                echo "On Ubuntu with Netplan/systemd-networkd:"
                echo ""
                echo "  Option A: sudo netplan apply"
                echo "    (Re-applies the Netplan config without restarting everything)"
                echo ""
                echo "  Option B: sudo systemctl restart systemd-networkd"
                echo "    (Restarts the entire networking backend)"
                echo ""
                echo "Would you like to restart networking now? (y/n)"
                read -p "> " RESTART
                if [ "$RESTART" = "y" ]; then
                    echo "Running: sudo netplan apply"
                    sudo netplan apply
                    echo "Done. Check your connection with: ip a"
                fi
            else
                echo "On CentOS 10 with NetworkManager:"
                echo ""
                echo "  Option A: sudo nmcli con up <connection-name>"
                echo "    (Restarts a specific connection)"
                echo ""
                echo "  Option B: sudo systemctl restart NetworkManager"
                echo "    (Restarts the entire NetworkManager service)"
                echo ""
                echo "Would you like to restart NetworkManager now? (y/n)"
                read -p "> " RESTART
                if [ "$RESTART" = "y" ]; then
                    echo "Running: sudo systemctl restart NetworkManager"
                    sudo systemctl restart NetworkManager
                    echo "Done. Check your connection with: ip a"
                fi
            fi
            pause
            ;;
 
        # Option 8: Exit
        8)
            echo ""
            echo "Exiting troubleshooting tool. Good luck!"
            echo ""
            RUNNING=false
            ;;
 
        # Invalid Input
        *)
            echo ""
            echo "Invalid option. Please select a number between 1 and 8."
            pause
            ;;
    esac
done
 
