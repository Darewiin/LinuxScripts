Script: task5_block_telnet.sh
#!/bin/bash
# task5_block_telnet.sh - Block telnet

# Block incoming telnet
sudo iptables -A INPUT -p tcp --dport 23 -j DROP

# Block outgoing telnet
sudo iptables -A OUTPUT -p tcp --dport 23 -j DROP

echo 'Telnet blocked on port 23.'
sudo iptables -L -v -n
