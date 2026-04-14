# Save original state first
mkdir -p ~/iptables_backups
sudo iptables -L -v -n > ~/iptables_backups/iptables_original.txt
sudo iptables -t nat -L -v -n >> ~/iptables_backups/iptables_original.txt

# Stop and disable firewalld
sudo systemctl stop firewalld
sudo systemctl disable firewalld
sudo systemctl mask firewalld

# Install iptables-services
sudo dnf install -y iptables-services

# Enable and start iptables
sudo systemctl enable iptables
sudo systemctl start iptables

# Verify
sudo iptables -L -v -n
