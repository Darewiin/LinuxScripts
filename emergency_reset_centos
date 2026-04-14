sudo iptables -P INPUT DROP
sudo iptables -P FORWARD DROP
sudo iptables -P OUTPUT ACCEPT

sudo iptables -A INPUT -i lo -j ACCEPT
sudo iptables -A OUTPUT -o lo -j ACCEPT
sudo iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# Allow SCP/SSH from my personal Mac (10.211.55.2)

sudo iptables -A INPUT -p tcp -s 10.211.55.2 --dport 22 -m state --state NEW,ESTABLISHED -j ACCEPT

sudo iptables -A OUTPUT -p tcp --dport 22 -d 10.211.55.2 -m state --state ESTABLISHED -j ACCEPT

# task1_webserver.sh - Open web ports, forward 80 to 8080

sudo iptables -A INPUT -p tcp --dport 80 -m state --state NEW,ESTABLISHED -j ACCEPT
sudo iptables -A OUTPUT -p tcp --sport 80 -m state --state ESTABLISHED -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 443 -m state --state NEW,ESTABLISHED -j ACCEPT
sudo iptables -A OUTPUT -p tcp --sport 443 -m state --state ESTABLISHED -j ACCEPT
sudo iptables -t nat -A PREROUTING -p tcp --dport 80 -j REDIRECT --to-port 8080
sudo iptables -A INPUT -p tcp --dport 8080 -m state --state NEW,ESTABLISHED -j ACCEPT
sudo iptables -A OUTPUT -p tcp --sport 8080 -m state --state ESTABLISHED -j ACCEPT
sudo sysctl -w net.ipv4.ip_forward=1

# task2_mysql.sh - Open MySQL port for trusted hosts only

TRUSTED_IP="192.168.1.100"
TRUSTED_IP2="192.168.1.101"

sudo iptables -A INPUT -p tcp -s $TRUSTED_IP --dport 3306 \
  -m state --state NEW,ESTABLISHED -j ACCEPT
sudo iptables -A OUTPUT -p tcp --sport 3306 -d $TRUSTED_IP \
  -m state --state ESTABLISHED -j ACCEPT
sudo iptables -A INPUT -p tcp -s $TRUSTED_IP2 --dport 3306 \
  -m state --state NEW,ESTABLISHED -j ACCEPT
sudo iptables -A OUTPUT -p tcp --sport 3306 -d $TRUSTED_IP2 \
  -m state --state ESTABLISHED -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 3306 -j DROP

# task3_ssh_allow.sh - Allow incoming and outgoing SSH

sudo iptables -A INPUT -p tcp --dport 22 -m state --state NEW,ESTABLISHED -j ACCEPT
sudo iptables -A OUTPUT -p tcp --sport 22 -m state --state ESTABLISHED -j ACCEPT
sudo iptables -A OUTPUT -p tcp --dport 22 -m state --state NEW,ESTABLISHED -j ACCEPT
sudo iptables -A INPUT -p tcp --sport 22 -m state --state ESTABLISHED -j ACCEPT



#finish
sudo iptables -L -v -n
sudo iptables -t nat -L -v -n
