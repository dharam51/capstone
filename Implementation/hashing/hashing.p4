#include <core.p4>
#include <v1model.p4>

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
    // Fix : Map below identified rules to MAC addresses so that routing happens
    action route_to_h1() {
        standard_metadata.egress_spec = 1;
    }

    action route_to_h2() {
        standard_metadata.egress_spec = 2;
    }

    action route_to_h3() {
        standard_metadata.egress_spec = 3;
    }

    apply {
        bit<64> combined_ips = ((bit<64>)hdr.ipv4.srcAddr << 32) | (bit<64>)hdr.ipv4.dstAddr;
        meta.combined_hash_value = (bit<16>)(combined_ips % 65536);

        // Make a decision based on LSB of the hash value
        if (meta.combined_hash_value <= 21844) {
            route_to_h1();
        } else if (meta.combined_hash_value <= 43690) {
            route_to_h2();
        } else {
            route_to_h3();
        }
    }
}

control MyEgress(inout headers hdr, inout metadata meta, inout standard_metadata_t standard_metadata) {
    apply {
        // Empty for now
    }
}

control MyChecksum(inout headers hdr, inout metadata meta) {
    apply {
        // Empty for now
    }
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

// By using this method, the hash value calculated from the combination of source and destination IP addresses is used to make a routing decision directly in the P4 data plane, without needing any control plane configuration.
