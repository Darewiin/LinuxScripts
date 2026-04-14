#!/bin/bash
# task1_webserver.sh - Open web ports, forward 80 to 8080

# Allow incoming HTTP (port 80)
sudo iptables -A INPUT -p tcp --dport 80 -m state --state NEW,ESTABLISHED -j ACCEPT
sudo iptables -A OUTPUT -p tcp --sport 80 -m state --state ESTABLISHED -j ACCEPT

# Allow incoming HTTPS (port 443)
sudo iptables -A INPUT -p tcp --dport 443 -m state --state NEW,ESTABLISHED -j ACCEPT
sudo iptables -A OUTPUT -p tcp --sport 443 -m state --state ESTABLISHED -j ACCEPT

# Port forwarding: redirect incoming port 80 to port 8080
sudo iptables -t nat -A PREROUTING -p tcp --dport 80 -j REDIRECT --to-port 8080

# Allow traffic on port 8080 (forwarded traffic arrives here)
sudo iptables -A INPUT -p tcp --dport 8080 -m state --state NEW,ESTABLISHED -j ACCEPT
sudo iptables -A OUTPUT -p tcp --sport 8080 -m state --state ESTABLISHED -j ACCEPT

# Enable IP forwarding at the kernel level
sudo sysctl -w net.ipv4.ip_forward=1

echo 'Web server rules applied.'
sudo iptables -L -v -n
sudo iptables -t nat -L -v -n
