#include <core.p4>
#include <v1model.p4>

// Ethernet header definition
header ethernet_t {
    bit<48> dstAddr;      // Destination MAC address
    bit<48> srcAddr;      // Source MAC address
    bit<16> etherType;    // Ethertype field to indicate the type of payload (e.g., IPv4)
}

// IPv4 header definition
header ipv4_t {
    bit<4>  version;          // IPv4 version
    bit<4>  ihl;              // IP header length
    bit<8>  diffserv;         // Differentiated Services Code Point (DSCP) and Explicit Congestion Notification (ECN)
    bit<16> totalLen;         // Total length of the IP packet
    bit<16> identification;   // Identification field for fragmentation
    bit<3>  flags;            // Flags for fragmentation
    bit<13> fragOffset;       // Fragment offset
    bit<8>  ttl;              // Time to live
    bit<8>  protocol;         // Protocol number (e.g., 6 for TCP)
    bit<16> hdrChecksum;      // IP header checksum
    bit<32> srcAddr;          // Source IP address
    bit<32> dstAddr;          // Destination IP address
}

// Aggregate struct to hold all the headers
struct headers {
    ethernet_t ethernet;  // Ethernet header
    ipv4_t ipv4;          // IPv4 header
}

// Metadata structure to hold additional information, in this case, a hash value
struct metadata {
    bit<16> hash_value;
}

// Threshold for determining heavy hitters
const bit<32> THRESHOLD = 10;

// Packet parser logic
parser MyParser(packet_in packet, out headers hdr, inout metadata meta, inout standard_metadata_t standard_metadata) {
    state start {
        packet.extract(hdr.ethernet);   // Extract Ethernet header
        transition parse_ipv4;          // Transition to parse IPv4 header
    }
    state parse_ipv4 {
        packet.extract(hdr.ipv4);       // Extract IPv4 header
        transition accept;              // Finish parsing
    }
}

// Register for counting occurrences of each source IP
register<bit<32>>(65536) ip_count;        

// Register to store heavy hitters based on source IP
register<bit<32>>(65536) heavy_hitters;    

control MyIngress(inout headers hdr, inout metadata meta, inout standard_metadata_t standard_metadata) {
    // Action to forward a packet to a specific port
    action forward(bit<9> egress_port) {
        standard_metadata.egress_spec = egress_port;
    }

    // Action to drop a packet
    action _drop() {
        mark_to_drop(standard_metadata);
    }

    // Table to implement MAC-to-port forwarding
    table mac_to_port {
        key = {
            hdr.ethernet.dstAddr : exact;   // Key based on destination MAC address
        }
        actions = {
            forward;   // Forward to appropriate port
            _drop;     // Drop the packet
        }
        size = 1024;
        default_action = _drop();  // Default action is to drop
    }

    // Table to store heavy hitters based on source IP
    table heavy_hitters_table {
        key = {
            hdr.ipv4.srcAddr: exact;  // Key based on source IP
        }
        actions = {
            forward;   // Forward the packet
            _drop;     // Drop the packet
        }
        size = 1024;
        default_action = _drop();  // Default action is to drop
    }

    apply {
        // Apply the MAC-to-port forwarding table
        mac_to_port.apply();

        // Compute hash based on source IP
        bit<32> ip_as_index = hdr.ipv4.srcAddr;
        bit<32> current_count;
        
        // Read current count of packets from this source IP
        ip_count.read(current_count, ip_as_index);
        current_count = current_count + 1;
        
        // Update the count
        ip_count.write(ip_as_index, current_count);

        // Check if the count has exceeded the threshold for heavy hitters
        if (current_count > THRESHOLD) {
            bit<32> current_count_1;
            
            // Read current count of packets identified as heavy hitters
            heavy_hitters.read(current_count_1,ip_as_index);
            current_count_1 = current_count_1 + 1;
            
            // Update the heavy hitter count
            heavy_hitters.write(ip_as_index, current_count_1);
        }

        // If the packet is from a heavy hitter, apply the heavy hitters table
        if (current_count > THRESHOLD) {
            heavy_hitters_table.apply();
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
        packet.emit(hdr.ethernet);  // Emit Ethernet header
        packet.emit(hdr.ipv4);      // Emit IPv4 header
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
