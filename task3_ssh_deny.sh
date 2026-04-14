#!/bin/bash
# task3_ssh_deny.sh - Block ALL SSH traffic
# WARNING: If you're connected via SSH you WILL lose your connection!
# Make sure you have console access before running this.

# Remove any existing SSH allow rules first
sudo iptables -D INPUT -p tcp --dport 22 -m state --state NEW,ESTABLISHED -j ACCEPT 2>/dev/null
sudo iptables -D OUTPUT -p tcp --sport 22 -m state --state ESTABLISHED -j ACCEPT 2>/dev/null
sudo iptables -D OUTPUT -p tcp --dport 22 -m state --state NEW,ESTABLISHED -j ACCEPT 2>/dev/null
sudo iptables -D INPUT -p tcp --sport 22 -m state --state ESTABLISHED -j ACCEPT 2>/dev/null

# Drop all SSH traffic
sudo iptables -A INPUT -p tcp --dport 22 -j DROP
sudo iptables -A OUTPUT -p tcp --dport 22 -j DROP
sudo iptables -A INPUT -p tcp --sport 22 -j DROP
sudo iptables -A OUTPUT -p tcp --sport 22 -j DROP

echo 'SSH DENY rules applied. All SSH is now blocked.'
sudo iptables -L -v -n

