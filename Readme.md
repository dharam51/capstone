    - This implementation is very minimum to understand implemented optimizations in below paper
        https://www.usenix.org/system/files/nsdi22-paper-namkung.pdf
        Paper implementation with algorithms is more complex.
    - This can be extended to more complex use cases.
        - tables can be filled using `switch_cli` on control plane. Given we know nature of hash values.
        - More complex hash functions will give better results and variety of hash values to avoid collisions.
        - This code uses basic hash computation
    - If time permits implement single univmon algorithm with all the optimizations.
    
    **TCAM** : 
    - What is TCAM (Ternary Content-Addressable Memory) -  High Speed memory which operates with three possible states: 0, 1, or "X" (where "X" is a wildcard).
    - LPM - Longest Prefix match. Helps in identifying which level/bucket to update after hashing based on matched pattern.
    - Authors used LPM to identify which level to update in multi-level sketch. Instead of computing hash values again.

    1. O3 uses LPM on hash value to identify buckets of the packets.
    2. In multiple sketches, using lpm count of hash calls can be reduced because same seed hash function can be use across.
    3. Current Implementation add packets to buckets based on hash function and assumes LPM as /32(match whole IP address instead of subnet address)
    4. This implementation can be extended further to support LPM pattern matching on src IP address of variable length.
    5. Need to fill `tbl_select_level table` from control plane to decide which level/bucket to select.

    Paper Implementation.
    1. Calculate hash value based on some flow key.(srcIP address)
    2. Use P4 lpm to decide buckets based on the hash value obtained.

    Note : There are some cases where code do not perform as expected, because this implementation is approximation of tofino implementation but for bmv2 switch. Performance can be improved by selecting proper hash function and filling lpm table as appropriate.

    Broken : 
        - At times random register count is incremented.
        - Above behaviour due to nature of hash values generated.
        - Real world scenarios with different IP address might yield more appropriate behaviour.
        - Tested setup with Ping command. Can be extended to more complex commands

    Checkpoints:
        - Setup simple mininet topology - Success
        - Ping command test - Success
        - Register updates as per srcIP address hash value- Success
        - Verification with switch logs - Success
        - Future : Work on broken behaviour.

    **HASHING**:
    - Reduce multiple hash calls to single hash calls.
    - Generated hash value can be used across multiple levels if flowkey is same across levels. (Idea is to reduce count of hash calls)
    - This implementation illustrates an example how single hash call on (srcIP + destIP) can be use for routing based on hash values instead of multiple hash calles
    - Above implementation can be extended for complex use cases with advance hashing techniques and combination among different flowkeys.

    Checkpoints:
        - Setup simple mininet topology - Success
        - Ping command test - Failure (Some error in mapping of egressPort to MAC address)
        - Different egress port selection based on hash value - Success
        - Verification with switch logs - Success
        - Future : Explore more complex implementation with multi level sketches.

    

    TODO : 
        1. Implement heavy flow key.
        2. Explore future steps for each implementation.
        3. Implement single univmon algorithm with all optimizations.

    Different Scenarios/Examples:
        - Multi level sketches can be implemented optimally using proposed optimizations.(univmon)
        - This implementation can be extended for variety of flowkey combinations
            (srcIP + destIP), (srcIP + destMAC), (srcPort + destIP) and so on.
        - Knowing nature of hash function and specific flowkeys we are dealing with,can help in populating different control plane tables optimally.