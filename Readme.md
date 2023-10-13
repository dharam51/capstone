    O3
    1. O3 uses LPM on hash value to identify buckets of the packets.
    2. In multiple sketches, using lpm count of hash calls can be reduced because same seed hash function can be use across.
    3. Current Implementation add packets to buckets based on hash function and assumes LPM as /32(match whole IP address instead of subnet address)
    4. This implementation can be extended further to support LPM pattern matching on src IP address of variable length.
    5. Need to fill `tbl_select_level table` from control plane to decide which level/bucket to select.

    Paper Implementation.
    1. Calculate hash value based on some flow key.(srcIP address)
    2. Use P4 lpm to decide buckets based on the hash value obtained.

    Note : There are some cases where code do not perform as expected, because this implementation is approximation of tofino implementation but for bmv2 switch. Performance can be improved by selecting proper hash function and filling lpm table as appropriate.
