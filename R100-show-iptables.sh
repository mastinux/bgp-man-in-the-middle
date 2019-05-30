
#echo "------------------------------filter------------------------------"
#sudo python ./run.py --node R100 --cmd "iptables -t filter -nvL"
echo "------------------------------nat------------------------------"
sudo python ./run.py --node R100 --cmd "iptables -t nat -nvL POSTROUTING"
echo "------------------------------mangle------------------------------"
sudo python ./run.py --node R100 --cmd "iptables -t mangle -nvL PREROUTING"
echo "------------------------------------------------------------"

