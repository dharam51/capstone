"""
simple_switch_CLI :

    simple_switch_CLI --thrift-port 9090
    table_dump <table_name>

    - Forwarding table entries to add
    table_add mac_to_switch_port_mapping forward 00:00:00:00:00:01 => 1
    table_add mac_to_switch_port_mapping forward 00:00:00:00:00:02 => 2
    
    - Control Plane commands :: 
    table_add tbl_select_level set_bucket 131/32 => 1
    table_add tbl_select_level set_bucket 132/32 => 2

    The /32 here indicates that we are matching all 32 bits exactly. This makes our lpm effectively an exact match for the specific hash value.

mininet hosts:
        h1 arp -s 10.1.2.4 00:00:00:00:00:02
        h2 arp -s 10.1.2.3 00:00:00:00:00:01
bmv2 file:
        - o3.json
register_read ip_count_register <index>
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
        self.cmd('simple_switch --log-console -i 1@s1-eth1 -i 2@s1-eth2 o3.json >> logs.txt &')

    def stop(self):
        "Stop a P4 switch"
        self.cmd('kill %simple_switch')

class SimpleP4Topo(Topo):
    def __init__(self, **opts):
        Topo.__init__(self, **opts)

        h1 = self.addHost('h1', ip='10.1.2.3/24', mac='00:00:00:00:00:01')
        h2 = self.addHost('h2', ip='10.1.2.4/24', mac='00:00:00:00:00:02')

        # Use the custom P4Switch class for the s1 switch
        s1 = self.addSwitch('s1', cls=P4Switch)

        self.addLink(h1, s1)
        self.addLink(h2, s1)

if __name__ == '__main__':
    setLogLevel('info')
    net = Mininet(topo=SimpleP4Topo(), link=TCLink, controller=None)
    net.start()
    CLI(net)
    net.stop()
