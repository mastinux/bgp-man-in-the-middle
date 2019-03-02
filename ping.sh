#!/bin/bash

lxterminal -e "/bin/bash -c 'echo \"origin h100-1 destination h200-1\"; sudo python ./run.py --snode h100-1 --dnode h200-1 --cmd ping'" &
lxterminal -e "/bin/bash -c 'echo \"origin h200-1 destination h100-1\"; sudo python ./run.py --snode h200-1 --dnode h100-1 --cmd ping'" &
