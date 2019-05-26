#!/bin/bash

# sudo python ./run.py --node h40-1 --cmd 'ping -c 1 10.100.0.1'

sudo python ./run.py --node h40-1 --cmd 'traceroute -n -m 5 10.100.0.1'

# sudo python ./run.py --node h40-1 --cmd 'traceroute -n -m 5 10.101.0.1'

./show-nat.sh
