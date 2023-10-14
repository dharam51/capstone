    - This implementation is very minimum to understand implemented optimizations.
    - This can be extended to more complex use cases.
        - tables can be filled using `switch_cli` on control plane. Given we know nature of hash values.
        - More complex hash functions will give better results and variety of hash values to avoid collisions.
        - This code uses basic hash computation
    
    **TCAM** : 
    - What is TCAM - ?
    - LPM - ?

    1. O3 uses LPM on hash value to identify buckets of the packets.
    2. In multiple sketches, using lpm count of hash calls can be reduced because same seed hash function can be use across.
    3. Current Implementation add packets to buckets based on hash function and assumes LPM as /32(match whole IP address instead of subnet address)
    4. This implementation can be extended further to support LPM pattern matching on src IP address of variable length.
    5. Need to fill `tbl_select_level table` from control plane to decide which level/bucket to select.

    Paper Implementation.
    1. Calculate hash value based on some flow key.(srcIP address)
    2. Use P4 lpm to decide buckets based on the hash value obtained.

    Note : There are some cases where code do not perform as expected, because this implementation is approximation of tofino implementation but for bmv2 switch. Performance can be improved by selecting proper hash function and filling lpm table as appropriate.

    **HASHING**:
    - Reduce multiple hash calls to single hash calls.
    - Generated hash value can be used across multiple levels if flowkey is same across levels. (Idea is to reduce count of hash calls)
    - This implementation illustrates an example how single hash call (srcIP + destIP) can be use for routing based on hash values.
    - Above implementation can be extended for complex use cases with advance hashing techniques and combination among different flowkeys.

