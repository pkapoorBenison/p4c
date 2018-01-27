#include <core.p4>
#include <v1model.p4>

typedef bit<32> IPv4Address;
header ethernet_t {
    bit<48> dstAddr;
    bit<48> srcAddr;
    bit<16> etherType;
}

header ipv4_t {
    bit<4>      version;
    bit<4>      ihl;
    bit<8>      diffserv;
    bit<16>     totalLen;
    bit<16>     identification;
    bit<3>      flags;
    bit<13>     fragOffset;
    bit<8>      ttl;
    bit<8>      protocol;
    bit<16>     hdrChecksum;
    IPv4Address srcAddr;
    IPv4Address dstAddr;
}

struct headers {
    ethernet_t ethernet;
    ipv4_t     ipv4;
}

struct mystruct1_t {
    bit<16> hash1;
    bool    hash_drop;
}

struct metadata {
    mystruct1_t mystruct1;
}

parser parserI(packet_in pkt, out headers hdr, inout metadata meta, inout standard_metadata_t stdmeta) {
    state start {
        pkt.extract<ethernet_t>(hdr.ethernet);
        transition select(hdr.ethernet.etherType) {
            16w0x800: parse_ipv4;
            default: accept;
        }
    }
    state parse_ipv4 {
        pkt.extract<ipv4_t>(hdr.ipv4);
        transition accept;
    }
}

struct tuple_0 {
    bit<32> field;
    bit<32> field_0;
    bit<8>  field_1;
}

control cIngress(inout headers hdr, inout metadata meta, inout standard_metadata_t stdmeta) {
    @name("NoAction") action NoAction_0() {
    }
    @name("hash_drop_decision") action hash_drop_decision_0() {
        hash<bit<16>, bit<16>, tuple_0, bit<32>>(meta.mystruct1.hash1, HashAlgorithm.crc16, 16w0, { hdr.ipv4.srcAddr, hdr.ipv4.dstAddr, hdr.ipv4.protocol }, 32w0xffff);
        meta.mystruct1.hash_drop = meta.mystruct1.hash1 < 16w0x8000;
    }
    @name("guh") table guh {
        key = {
            hdr.ipv4.dstAddr: exact @name("hdr.ipv4.dstAddr") ;
        }
        actions = {
            hash_drop_decision_0();
        }
        default_action = hash_drop_decision_0();
    }
    @name("debug_table") table debug_table {
        key = {
            meta.mystruct1.hash1    : exact @name("meta.mystruct1.hash1") ;
            meta.mystruct1.hash_drop: exact @name("meta.mystruct1.hash_drop") ;
        }
        actions = {
            NoAction_0();
        }
        default_action = NoAction_0();
    }
    @hidden action act() {
        hdr.ethernet.dstAddr = meta.mystruct1.hash1 ++ 7w0 ++ (bit<1>)meta.mystruct1.hash_drop ++ 8w0 ++ 16w0xdead;
    }
    @hidden action act_0() {
        hdr.ethernet.dstAddr = meta.mystruct1.hash1 ++ 7w0 ++ (bit<1>)meta.mystruct1.hash_drop ++ 8w0 ++ 16w0xc001;
    }
    @hidden table tbl_act {
        actions = {
            act();
        }
        const default_action = act();
    }
    @hidden table tbl_act_0 {
        actions = {
            act_0();
        }
        const default_action = act_0();
    }
    apply {
        if (hdr.ipv4.isValid()) {
            guh.apply();
            debug_table.apply();
            if (meta.mystruct1.hash_drop) 
                tbl_act.apply();
            else 
                tbl_act_0.apply();
        }
    }
}

control cEgress(inout headers hdr, inout metadata meta, inout standard_metadata_t stdmeta) {
    apply {
    }
}

control verifyChecksum(inout headers hdr, inout metadata meta) {
    apply {
    }
}

control updateChecksum(inout headers hdr, inout metadata meta) {
    apply {
    }
}

control DeparserI(packet_out packet, in headers hdr) {
    apply {
        packet.emit<ethernet_t>(hdr.ethernet);
        packet.emit<ipv4_t>(hdr.ipv4);
    }
}

V1Switch<headers, metadata>(parserI(), verifyChecksum(), cIngress(), cEgress(), updateChecksum(), DeparserI()) main;
