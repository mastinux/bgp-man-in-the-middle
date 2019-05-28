#!/bin/bash

# https://gist.github.com/nerdalert/a1687ae4da1cc44a437d

sudo rm /tmp/err

sudo python ./run.py --node h100-1 --cmd "iptables -t filter -F 2>> /tmp/err"
sudo python ./run.py --node h100-1 --cmd "iptables -t nat -F 2>> /tmp/err"

#sudo python ./run.py --node h100-1 --cmd "iptables -t nat -A PREROUTING -i h100-1-eth1 -j DNAT --to-destination 10.100.0.1 2>> /tmp/err"
sudo python ./run.py --node h100-1 --cmd "iptables -t nat -A INPUT -j ACCEPT 2>> /tmp/err"
sudo python ./run.py --node h100-1 --cmd "iptables -t filter -A INPUT -j ACCEPT 2>> /tmp/err"
sudo python ./run.py --node h100-1 --cmd "iptables -t filter -A FORWARD -j ACCEPT 2>> /tmp/err"
sudo python ./run.py --node h100-1 --cmd "iptables -t filter -A OUTPUT -j ACCEPT 2>> /tmp/err"
sudo python ./run.py --node h100-1 --cmd "iptables -t nat -A OUTPUT -j ACCEPT 2>> /tmp/err"
#sudo python ./run.py --node h100-1 --cmd "iptables -t nat -A POSTROUTING -o h100-1-eth0 -j SNAT --to-source 10.100.0.1 2>> /tmp/err"

sudo python ./run.py --node h100-1 --cmd "echo 1 > /proc/sys/net/ipv4/ip_forward 2>> /tmp/err"

cat /tmp/err

