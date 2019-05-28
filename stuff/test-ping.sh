#!/bin/bash

reset

echo "########## 10.20.0.1 ping 10.200.0.1 ##########"
sudo python ./run.py --node h20-1 --cmd 'ping -c 1 10.200.0.1'
echo
echo "########## 10.10.0.1 ping 10.200.0.1 ##########"
sudo python ./run.py --node h10-1 --cmd 'ping -c 1 10.200.0.1'
echo
echo "########## 10.100.0.1 ping 10.200.0.1 ##########"
sudo python ./run.py --node h100-1 --cmd 'ping -c 1 10.200.0.1'
echo
echo "########## 10.40.0.1 ping 10.200.0.1 ##########"
sudo python ./run.py --node h40-1 --cmd 'ping -c 1 10.200.0.1'
echo
echo "########## 10.30.0.1 ping 10.200.0.1 ##########"
sudo python ./run.py --node h30-1 --cmd 'ping -c 1 10.200.0.1'
echo
