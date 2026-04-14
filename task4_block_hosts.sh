#!/bin/bash
# task4_block_hosts.sh - Block/allow specific IPs and MACs

# ==== CONFIGURE THESE ====
BLOCKED_IP="10.211.55.6"
ALLOWED_IP="10.211.55.2"
BLOCKED_MAC=""
ALLOWED_MAC="ae:07:75:c0:b4:64"
# =========================

# Block specific IPs
sudo iptables -A INPUT -s $BLOCKED_IP -j DROP
sudo iptables -A INPUT -s $BLOCKED_IP2 -j DROP

# Allow a specific IP
sudo iptables -A INPUT -s $ALLOWED_IP -j ACCEPT

# Block a specific MAC address
sudo iptables -A INPUT -m mac --mac-source $BLOCKED_MAC -j DROP

# Allow a specific MAC address
sudo iptables -A INPUT -m mac --mac-source $ALLOWED_MAC -j ACCEPT

# Block an entire subnet
sudo iptables -A INPUT -s 10.0.0.0/24 -j DROP

echo 'Host/MAC rules applied.'
sudo iptables -L -v -n
