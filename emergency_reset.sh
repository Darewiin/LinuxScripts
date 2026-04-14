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
