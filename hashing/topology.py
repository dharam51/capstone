"""
h1 arp -s 10.1.2.4 00:00:00:00:00:02
h1 arp -s 10.1.2.5 00:00:00:00:00:03
h2 arp -s 10.1.2.3 00:00:00:00:00:01
h2 arp -s 10.1.2.5 00:00:00:00:00:03
h3 arp -s 10.1.2.3 00:00:00:00:00:01
h3 arp -s 10.1.2.4 00:00:00:00:00:02

"""

from mininet.net import Mininet
from mininet.topo import Topo
from mininet.link import TCLink
from mininet.cli import CLI
from mininet.log import setLogLevel
from mininet.node import Switch

# Define a custom switch class to run BMv2's simple_switch
class P4Switch(Switch):
    def start(self, controllers):
        "Start up a new P4 switch"
        self.cmd('simple_switch --log-console -i 1@s1-eth1 -i 2@s1-eth2 -i 3@s1-eth3 hashing.json >> logs.txt &')

    def stop(self):
        "Stop a P4 switch"
        self.cmd('kill %simple_switch')

class SimpleP4Topo(Topo):
    def __init__(self, **opts):
        Topo.__init__(self, **opts)

        h1 = self.addHost('h1', ip='10.1.2.3/24', mac='00:00:00:00:00:01')
        h2 = self.addHost('h2', ip='10.1.2.4/24', mac='00:00:00:00:00:02')
        h3 = self.addHost('h3', ip='10.1.2.5/24', mac='00:00:00:00:00:03')

        # Use the custom P4Switch class for the s1 switch
        s1 = self.addSwitch('s1', cls=P4Switch)

        self.addLink(h1, s1)
        self.addLink(h2, s1)
        self.addLink(h3, s1)

if __name__ == '__main__':
    setLogLevel('info')
    net = Mininet(topo=SimpleP4Topo(), link=TCLink, controller=None)
    net.start()

    # Setting ARP entries
    h1, h2, h3 = net.get('h1'), net.get('h2'), net.get('h3')
    h1.cmd('arp -s 10.1.2.4 00:00:00:00:00:02')
    h1.cmd('arp -s 10.1.2.5 00:00:00:00:00:03')
    h2.cmd('arp -s 10.1.2.3 00:00:00:00:00:01')
    h2.cmd('arp -s 10.1.2.5 00:00:00:00:00:03')
    h3.cmd('arp -s 10.1.2.3 00:00:00:00:00:01')
    h3.cmd('arp -s 10.1.2.4 00:00:00:00:00:02')

    CLI(net)
    net.stop()
