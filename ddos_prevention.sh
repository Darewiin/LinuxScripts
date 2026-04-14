#!/bin/bash
# ddos_prevention.sh - Basic DDoS mitigation rules

# Drop packets that don't belong to any known connection
sudo iptables -A INPUT -m state --state INVALID -j DROP

# SYN flood protection - limit SYN packets to 1/sec, burst of 3
sudo iptables -A INPUT -p tcp --syn -m limit --limit 1/s --limit-burst 3 -j ACCEPT
sudo sysctl -w net.ipv4.tcp_syncookies=1

# Rate limit new connections to 60/min
sudo iptables -A INPUT -p tcp -m state --state NEW \
  -m limit --limit 60/min --limit-burst 20 -j ACCEPT

# Limit connections per IP on web ports (max 30)
sudo iptables -A INPUT -p tcp --dport 80 -m connlimit --connlimit-above 30 -j DROP
sudo iptables -A INPUT -p tcp --dport 443 -m connlimit --connlimit-above 30 -j DROP

# Block common port scan techniques
sudo iptables -A INPUT -p tcp --tcp-flags ALL ALL -j DROP    # XMAS scan
sudo iptables -A INPUT -p tcp --tcp-flags ALL NONE -j DROP   # NULL scan

# Drop fragments and rate limit ping
sudo iptables -A INPUT -f -j DROP
sudo iptables -A INPUT -p icmp --icmp-type echo-request -m limit --limit 1/s --limit-burst 4 -j ACCEPT
sudo iptables -A INPUT -p icmp --icmp-type echo-request -j DROP

echo 'DDoS prevention rules applied.'
