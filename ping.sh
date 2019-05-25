#!/bin/bash

echo; echo ----- origin h100-1 destination h200-1 -----; sudo python ./run.py --snode h100-1 --dnode h200-1 --cmd 'ping -c 1'
echo; echo ----- origin h10-1 destination h200-1 -----; sudo python ./run.py --snode h10-1 --dnode h200-1 --cmd 'ping -c 1'
echo; echo ----- origin h20-1 destination h200-1 -----; sudo python ./run.py --snode h20-1 --dnode h200-1 --cmd 'ping -c 1'
echo; echo ----- origin h30-1 destination h200-1 -----; sudo python ./run.py --snode h30-1 --dnode h200-1 --cmd 'ping -c 1'
echo; echo ----- origin h40-1 destination h200-1 -----; sudo python ./run.py --snode h40-1 --dnode h200-1 --cmd 'ping -c 1'
