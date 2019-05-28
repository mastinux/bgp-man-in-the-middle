#!/bin/bash

reset

sudo python ./run.py --node R100 --cmd 'tcpdump -nli R100-eth3 port not 179'
