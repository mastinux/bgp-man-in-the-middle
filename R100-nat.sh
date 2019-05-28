#!/bin/bash

# https://gist.github.com/nerdalert/a1687ae4da1cc44a437d

sudo rm /tmp/err

sudo python ./run.py --node R100 --cmd "iptables -t filter -F 2>> /tmp/err"
sudo python ./run.py --node R100 --cmd "iptables -t nat -F 2>> /tmp/err"

#sudo python ./run.py --node R100 --cmd "iptables -t nat -A PREROUTING -i R00-eth3 -j DNAT --to-destination 10.100.0.1 2>> /tmp/err"
#sudo python ./run.py --node R100 --cmd "iptables -t nat -A INPUT -j ACCEPT 2>> /tmp/err"
#sudo python ./run.py --node R100 --cmd "iptables -t filter -A INPUT -j ACCEPT 2>> /tmp/err"
#sudo python ./run.py --node R100 --cmd "iptables -t filter -A FORWARD -j ACCEPT 2>> /tmp/err"
#sudo python ./run.py --node R100 --cmd "iptables -t filter -A OUTPUT -j ACCEPT 2>> /tmp/err"
#sudo python ./run.py --node R100 --cmd "iptables -t nat -A OUTPUT -j ACCEPT 2>> /tmp/err"
sudo python ./run.py --node R100 --cmd "iptables -t nat -A POSTROUTING -o R100-eth2 -s 10.30.0.1 -j SNAT --to-source 9.0.110.2 2>> /tmp/err"
sudo python ./run.py --node R100 --cmd "iptables -t nat -A POSTROUTING -o R100-eth2 -s 10.40.0.1 -j SNAT --to-source 9.0.110.2 2>> /tmp/err"

cat /tmp/err

