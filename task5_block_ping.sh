#!/bin/bash
# task5_block_ping.sh - Block incoming ping

# Block incoming ping (ICMP echo-request, type 8)
sudo iptables -A INPUT -p icmp --icmp-type echo-request -j DROP

echo 'Ping blocked.'
sudo iptables -L -v -n
