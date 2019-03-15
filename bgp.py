#!/usr/bin/env python

import sys
import os

from mininet.topo import Topo
from mininet.net import Mininet
from mininet.log import lg, info, setLogLevel
from mininet.util import dumpNodeConnections, quietRun, moveIntf, waitListening
from mininet.cli import CLI
from mininet.node import Switch, OVSSwitch, Controller, RemoteController, Node
from subprocess import Popen, PIPE, check_output
from multiprocessing import Process
from argparse import ArgumentParser
from utils import log, log2

BGP_CONVERGENCE_TIME = 15

QUAGGA_STATE_DIR = '/var/run/quagga-1.2.4'

setLogLevel('info')
#setLogLevel('debug')

parser = ArgumentParser("Configure simple BGP network in Mininet.")
parser.add_argument('--sleep', default=3, type=int)
args = parser.parse_args()


class Router(Switch):
	"""
	Defines a new router that is inside a network namespace so that the
	individual routing entries don't collide.
	"""
	ID = 0
	def __init__(self, name, **kwargs):
		kwargs['inNamespace'] = True
		Switch.__init__(self, name, **kwargs)
		Router.ID += 1
		self.switch_id = Router.ID

	@staticmethod
	def setup():
		return

	def start(self, controllers):
		pass

	def stop(self):
		self.deleteIntfs()

	def log(self, s, col="magenta"):
		print T.colored(s, col)


class SimpleTopo(Topo):

	def __init__(self):
		# Add default members to class.
		super(SimpleTopo, self ).__init__()

		# The topology has one router per AS
		routers = []

		# R100, R200
		for i in xrange(2):
			router = self.addSwitch('R%d00' % (i+1))
			routers.append(router)

		# R10, R20, R30, R40
		for i in xrange(4):
			router = self.addSwitch('R%d0' % (i+1))
			routers.append(router)

		# adding hosts to routers
		hosts = []
		for router in routers:
			hostname = 'h%s-1' % router.replace('R', '')
			print router, hostname
			host = self.addNode(hostname)
			hosts.append(host)
			self.addLink(router, host)

		# adding links between routers
		self.addLink('R100', 'R10')
		self.addLink('R10', 'R20')
		self.addLink('R20', 'R200')
		self.addLink('R200', 'R30')
		self.addLink('R30', 'R40')
		self.addLink('R40', 'R100')
		#self.addLink('R20', 'R30')

		return


def getIP(hostname):
	AS, idx = hostname.replace('h', '').split('-')
	AS = int(AS)

	ip = '10.%s.0.%s/24' % (AS, idx)

	print hostname, ip

	return ip


def getGateway(hostname):
	AS, idx = hostname.replace('h', '').split('-')
	AS = int(AS)

	gw = '10.%s.0.254' % (AS)

	print hostname, gw

	return gw


def init_quagga_state_dir():
	if not os.path.exists(QUAGGA_STATE_DIR):
		os.makedirs(QUAGGA_STATE_DIR)

	os.system('chown mininet:mininet %s' % QUAGGA_STATE_DIR)

	return

	
def main():
	os.system("reset")

	os.system("rm -f /tmp/bgp-R?.pid /tmp/zebra-R?.pid 2> /dev/null")
	os.system("rm -f /tmp/R*.log /tmp/R*.pcap 2> /dev/null")
	os.system("rm logs/R*stdout 2> /dev/null")
	os.system("rm /tmp/hub.log /tmp/c*.log /tmp/attacks.* /tmp/atk1*.pcap " 		"2> /dev/null")
	os.system("rm /tmp/tcpdump*.out /tmp/tcpdump*.err 2> /dev/null")
	os.system("rm /tmp/R*-complete.out /tmp/R*-complete.err 2> /dev/null")

	os.system("mn -c > /dev/null 2>&1")

	os.system('pgrep zebra | xargs kill -9')
	os.system('pgrep bgpd | xargs kill -9')
	os.system('pgrep -f webserver.py | xargs kill -9')

	init_quagga_state_dir()

	net = Mininet(topo=SimpleTopo(), switch=Router)
	net.start()

	log("Configuring hosts ...")
	for host in net.hosts:
		host.cmd("ifconfig %s-eth0 %s" % (host.name, getIP(host.name)))
		host.cmd("route add default gw %s" % (getGateway(host.name)))
		print getGateway(host.name)

	log("Configuring routers ...")
	for router in net.switches:
		router.cmd("sysctl -w net.ipv4.ip_forward=1")
		router.waitOutput()

	log2("sysctl changes to take effect", args.sleep, col='cyan')

	for router in net.switches:
		router.cmd("tcpdump -i %s-eth1 -w /tmp/%s-eth1.pcap not arp > /tmp/tcpdump-%s-eth1.out 2> /tmp/tcpdump-%s-eth1.err &" % (router.name, router.name, router.name, router.name), shell=True)
		router.cmd("tcpdump -i %s-eth2 -w /tmp/%s-eth2.pcap not arp > /tmp/tcpdump-%s-eth2.out 2> /tmp/tcpdump-%s-eth2.err &" % (router.name, router.name, router.name, router.name), shell=True)
		router.cmd("tcpdump -i %s-eth3 -w /tmp/%s-eth3.pcap not arp > /tmp/tcpdump-%s-eth3.out 2> /tmp/tcpdump-%s-eth3.err &" % (router.name, router.name, router.name, router.name), shell=True)
		router.cmd("tcpdump -i %s-eth4 -w /tmp/%s-eth4.pcap not arp > /tmp/tcpdump-%s-eth4.out 2> /tmp/tcpdump-%s-eth4.err &" % (router.name, router.name, router.name, router.name), shell=True)

		router.cmd("~/quagga-1.2.4/zebra/zebra -f conf/zebra-%s.conf -d -i "
			"/tmp/zebra-%s.pid > logs/%s-zebra-stdout 2>&1" % \
			(router.name, router.name, router.name))
		router.waitOutput()

		router.cmd("~/quagga-1.2.4/bgpd/bgpd -f conf/bgpd-%s.conf -d -i "
			"/tmp/bgp-%s.pid > logs/%s-bgpd-stdout 2>&1" % \
			(router.name, router.name, router.name), shell=True)
		router.waitOutput()

		log("Starting zebra and bgpd on %s" % router.name)

		"""
		if router.name == "R100":
			router.cmd("ping 10.10.12.2 2>&1 > /tmp/ping-from-%s.txt &" \
			% router.name, shell=True)
		else:
			router.cmd("ping 10.10.12.1 2>&1 > /tmp/ping-from-%s.txt &" \
			% router.name, shell=True)
		"""

	log2("BGP convergence", BGP_CONVERGENCE_TIME, 'cyan')

	CLI(net)

	net.stop()

	os.system('pgrep zebra | xargs kill -9')
	os.system('pgrep bgpd | xargs kill -9')
	os.system('pgrep -f webserver.py | xargs kill -9')

	#os.system('sudo wireshark /tmp/R100-eth2.pcap -Y \'icmp\' &')
	#os.system('sudo wireshark /tmp/R100-eth3.pcap -Y \'icmp\' &')
	#os.system('sudo wireshark /tmp/R10-eth3.pcap -Y \'icmp\' &')
	#os.system('sudo wireshark /tmp/R40-eth2.pcap -Y \'icmp\' &')
	#os.system('sudo wireshark /tmp/R30-eth2.pcap -Y \'icmp\' &')
	#os.system('sudo wireshark /tmp/R20-eth3.pcap -Y \'icmp\' &')
	#os.system('sudo wireshark /tmp/R200-eth1.pcap -Y \'icmp\' &')


if __name__ == "__main__":
	main()
