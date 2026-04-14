#!/bin/bash
# task3_ssh_allow.sh - Allow incoming and outgoing SSH

# Allow incoming SSH (people connecting TO this server)
sudo iptables -A INPUT -p tcp --dport 22 -m state --state NEW,ESTABLISHED -j ACCEPT
sudo iptables -A OUTPUT -p tcp --sport 22 -m state --state ESTABLISHED -j ACCEPT

# Allow outgoing SSH (this server connecting TO other machines)
sudo iptables -A OUTPUT -p tcp --dport 22 -m state --state NEW,ESTABLISHED -j ACCEPT
sudo iptables -A INPUT -p tcp --sport 22 -m state --state ESTABLISHED -j ACCEPT

echo 'SSH ALLOW rules applied.'
sudo iptables -L -v -n
