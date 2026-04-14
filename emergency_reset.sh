#!/bin/bash
# task4_block_hosts.sh - Block/allow specific IPs and MACs


#use this script to reset the tables in case you need it

sudo iptables -F
sudo iptables -X
sudo iptables -t nat -F

sudo iptables -P INPUT DROP
sudo iptables -P FORWARD DROP
sudo iptables -P OUTPUT ACCEPT

sudo iptables -A INPUT -i lo -j ACCEPT
sudo iptables -A OUTPUT -o lo -j ACCEPT
sudo iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# SCP from your Mac
sudo iptables -A INPUT -p tcp -s 10.211.55.2 --dport 22 -m state --state NEW,ESTABLISHED -j ACCEPT

# MySQL - ALLOW rules BEFORE the DROP
sudo iptables -A INPUT -p tcp -s 10.211.55.2 --dport 3306 -m state --state NEW,ESTABLISHED -j ACCEPT
sudo iptables -A INPUT -p tcp -s 10.211.55.6 --dport 3306 -m state --state NEW,ESTABLISHED -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 3306 -j DROP


# task3_ssh_allow.sh - Allow incoming and outgoing SSH

# Allow incoming SSH (people connecting TO this server)
sudo iptables -A INPUT -p tcp --dport 22 -m state --state NEW,ESTABLISHED -j ACCEPT
sudo iptables -A OUTPUT -p tcp --sport 22 -m state --state ESTABLISHED -j ACCEPT

# Allow outgoing SSH (this server connecting TO other machines)
sudo iptables -A OUTPUT -p tcp --dport 22 -m state --state NEW,ESTABLISHED -j ACCEPT
sudo iptables -A INPUT -p tcp --sport 22 -m state --state ESTABLISHED -j ACCEPT




# task4_block_hosts.sh - Block/allow specific IPs and MACs

# ==== CONFIGURE THESE ====
BLOCKED_IP="10.211.55.6"
ALLOWED_IP="10.211.55.2"
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

sudo iptables -L -v -n
