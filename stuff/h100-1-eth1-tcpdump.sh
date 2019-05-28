#!/bin/bash

reset

sudo python ./run.py --node h100-1 --cmd 'tcpdump -nli h100-1-eth1 icmp'
