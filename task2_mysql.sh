#!/bin/bash
# task2_mysql.sh - Open MySQL port for trusted hosts only

# ==== CONFIGURE THESE ====
TRUSTED_IP="192.168.1.100"   # Replace with your trusted host
TRUSTED_IP2="192.168.1.101"  # Replace with your second server
# =========================

# Allow MySQL from trusted host 1
sudo iptables -A INPUT -p tcp -s $TRUSTED_IP --dport 3306 \
  -m state --state NEW,ESTABLISHED -j ACCEPT
sudo iptables -A OUTPUT -p tcp --sport 3306 -d $TRUSTED_IP \
  -m state --state ESTABLISHED -j ACCEPT

# Allow MySQL from trusted host 2
sudo iptables -A INPUT -p tcp -s $TRUSTED_IP2 --dport 3306 \
  -m state --state NEW,ESTABLISHED -j ACCEPT
sudo iptables -A OUTPUT -p tcp --sport 3306 -d $TRUSTED_IP2 \
  -m state --state ESTABLISHED -j ACCEPT

# Drop MySQL from everyone else
sudo iptables -A INPUT -p tcp --dport 3306 -j DROP

echo 'MySQL rules applied. Port 3306 open for trusted hosts only.'
sudo iptables -L -v -n
