// Compile : p4c --target bmv2 --arch v1model --std p4-16 o3.p4

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

struct metadata {
    bit<32> hash_value;
    bit<8>  bucket;
}



parser MyParser(packet_in packet, out headers hdr, inout metadata meta, inout standard_metadata_t standard_metadata) {
    state start {
        packet.extract(hdr.ethernet);
        transition parse_ipv4;
    }
    
    state parse_ipv4 {
        packet.extract(hdr.ipv4);
        transition compute_hash;
    }
    
    state compute_hash {
        meta.hash_value = hdr.ipv4.srcAddr % 256;  // Simple modulo-based hash
        
        transition accept;
    }
}



// Action to set the bucket based on match in the table
action set_bucket(inout metadata meta , bit<8> determined_bucket) {
    meta.bucket = determined_bucket;
}

register<bit<32>>(256) ip_count_register; // Assuming a maximum of 16384 unique IP addresses to track

// P4 table for longest prefix match on hash value to determine bucket
control MyIngress(inout headers hdr, inout metadata meta, inout standard_metadata_t standard_metadata) {
    
     // Action to forward the packet based on MAC address
    action forward(bit<9> outPort) {
        standard_metadata.egress_spec = outPort;
    }
    
    // L2 forwarding table
    table l2_forwarding {
        key = {
            hdr.ethernet.dstAddr: exact;
        }
        actions = {
            forward;
        }
        size = 4096;
        default_action = forward(0); // Default to port 0 if no match. Adjust as needed.
    }
    
    table tbl_select_level {
        key = {
            // lpm optimization was proposed in the paper to reduce total count of hashcalls.
            // Multiple if statements with individual hashcall gets replaced by lpm
            // This optimization levarages Hash call optimizations(O1 & O2)
            // O4 uses O3's TCAM implementation to optimize.
            // O1, O2 and O3 are linked. O3 is built on top of O1 and O2
            // O1 and O2 optimizations were done, therefore it was possible to implement O3
            meta.hash_value: lpm;  // LPM match on the hash value  
        }
        actions = {
            set_bucket(meta);
        }
        size = 256;  
        default_action = set_bucket(meta,255);  // Default bucket if no match
    }

    apply {
        tbl_select_level.apply();  // Apply the table to determine bucket using LPM
        
        bit<32> current_count;
        ip_count_register.read(current_count, meta.hash_value); // Read the current count for the src IP
        ip_count_register.write( meta.hash_value, current_count + 1); // Increment and write back

        //ip_count_register.read(current_count, meta.hash_value); // Read the current count for the src IP
        //ip_count_register.write(meta.hash_value, current_count + 1); // Increment and write back

        // Then, L2 forwarding to make sure packets are forwarded correctly
        l2_forwarding.apply();
    }
}

control MyEgress(inout headers hdr, inout metadata meta, inout standard_metadata_t standard_metadata) {
    apply {
        // Any egress processing if needed
    }
}


control MyChecksum(inout headers hdr, inout metadata meta) {
    apply { }
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
