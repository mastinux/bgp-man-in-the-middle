
echo "------------------------------filter------------------------------"
sudo python ./run.py --node h100-1 --cmd "iptables -t filter -nvL"
echo "------------------------------nat------------------------------"
sudo python ./run.py --node h100-1 --cmd "iptables -t nat -nvL"
echo "------------------------------------------------------------"
