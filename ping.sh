#!/bin/bash

lxterminal -e "/bin/bash -c 'echo \"origin h100-1 destination h10-1\"; sudo python ./run.py --snode h100-1 --dnode h10-1 --cmd \"ping -c 1\"'" &
lxterminal -e "/bin/bash -c 'echo \"origin h100-1 destination h20-1\"; sudo python ./run.py --snode h100-1 --dnode h20-1 --cmd \"ping -c 1\"'" &
lxterminal -e "/bin/bash -c 'echo \"origin h100-1 destination h30-1\"; sudo python ./run.py --snode h100-1 --dnode h30-1 --cmd \"ping -c 1\"'" &
lxterminal -e "/bin/bash -c 'echo \"origin h100-1 destination h40-1\"; sudo python ./run.py --snode h100-1 --dnode h40-1 --cmd \"ping -c 1\"'" &
lxterminal -e "/bin/bash -c 'echo \"origin h100-1 destination h200-1\"; sudo python ./run.py --snode h100-1 --dnode h200-1 --cmd \"ping -c 1\"'" &
