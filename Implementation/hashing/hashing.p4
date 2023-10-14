#include <core.p4>
#include <v1model.p4>

// Define Ethernet and IPv4 headers
header ethernet_t {
    bit<48> dstAddr;
    bit<48> srcAddr;
    bit<16> etherType;
}

header ipv4_t {
    bit<4>  version;
    bit<4>  ihl;
    bit<8>  diffserv;
    bit<16> totalLen;
    bit<16> identification;
    bit<3>  flags;
    bit<13> fragOffset;
    bit<8>  ttl;
    bit<8>  protocol;
    bit<16> hdrChecksum;
    bit<32> srcAddr;
    bit<32> dstAddr;
}

struct headers {
    ethernet_t ethernet;
    ipv4_t ipv4;
}

// Store combined hash value (srcIP + destIP)
struct metadata {
    bit<16> combined_hash_value;
}

parser MyParser(packet_in packet, out headers hdr, inout metadata meta, inout standard_metadata_t standard_metadata) {
    state start {
        packet.extract(hdr.ethernet);
        transition parse_ipv4;
    }
    
    state parse_ipv4 {
        packet.extract(hdr.ipv4);
        transition accept;
    }
}

control MyIngress(inout headers hdr, inout metadata meta, inout standard_metadata_t standard_metadata) {
    // Implemet : ping command.
    // Done : Mapped below identified rules to MAC addresses so that routing happens
    // Error : Ping still not working.
    // Mapping of egressPort to MAC address
    action set_dst_mac(bit<48> mac) {
        hdr.ethernet.dstAddr = mac;
    }
    
    // Populate table with control plane commands
    // Maps value between switch port and host MAC address.
    table switch_port_to_mac {
        key = {
            standard_metadata.egress_spec: exact;
        }
        actions = {
            set_dst_mac;
        }
        size = 1024;
        default_action = set_dst_mac(0);
    }

    // Set egressPort
    action route_to_h1() {
        standard_metadata.egress_spec = 1; // Switch port value
    }

    action route_to_h2() {
        standard_metadata.egress_spec = 2;
    }

    action route_to_h3() {
        standard_metadata.egress_spec = 3;
    }

    apply {

        // Compute hash value on (srcIP + destIP)
        bit<64> combined_ips = ((bit<64>)hdr.ipv4.srcAddr << 32) | (bit<64>)hdr.ipv4.dstAddr;
        meta.combined_hash_value = (bit<16>)(combined_ips % 65536);

        // egressPort decision based on hash value range.
        if (meta.combined_hash_value <= 21844) {
            route_to_h1();
        } else if (meta.combined_hash_value <= 43690) {
            route_to_h2();
        } else {
            route_to_h3();
        }
        switch_port_to_mac.apply();
    }
}

control MyEgress(inout headers hdr, inout metadata meta, inout standard_metadata_t standard_metadata) {
    apply {}
}

control MyChecksum(inout headers hdr, inout metadata meta) {
    apply {}
}

control MyDeparser(packet_out packet, in headers hdr) {
    apply {
        packet.emit(hdr.ethernet);
        packet.emit(hdr.ipv4);
    }
}

V1Switch(
    MyParser(),
    MyChecksum(),
    MyIngress(),
    MyEgress(),
    MyChecksum(),
    MyDeparser()
) main;
