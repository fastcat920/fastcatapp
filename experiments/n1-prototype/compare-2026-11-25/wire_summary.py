#!/usr/bin/env python3
"""Private server-side truncated capture -> anonymous IP-byte counters only."""
import struct,json,sys,collections
raw=open(sys.argv[1],'rb').read();magic=raw[:4];endian='<' if magic in (b'\xd4\xc3\xb2\xa1',b'\x4d\x3c\xb2\xa1') else '>';link=struct.unpack_from(endian+'I',raw,20)[0];offset={1:14,113:16,276:20}[link];pos=24;flows=collections.defaultdict(set);counts=collections.defaultdict(lambda:collections.defaultdict(int))
while pos+16<=len(raw):
 sec,usec,cap,original=struct.unpack_from(endian+'IIII',raw,pos);pos+=16;p=raw[pos:pos+cap];pos+=cap
 if len(p)<offset+24 or p[offset]>>4!=4:continue
 ip=p[offset:];ihl=(ip[0]&15)*4;proto=ip[9]
 if proto not in (6,17) or len(ip)<ihl+4:continue
 src,dst=struct.unpack_from('!HH',ip,ihl);port=next((x for x in [18466,18468,18469] if x==src or x==dst),None)
 if not port:continue
 direction='down' if src==port else 'up';flows[port].add((bytes(ip[12:16]) if dst==port else bytes(ip[16:20]),src if dst==port else dst));c=counts[port];c[direction+'_packets']+=1;c[direction+'_captured_ip_bytes']+=int.from_bytes(ip[2:4],'big');c[direction+'_original_capture_bytes']+=original
for port,v in flows.items():counts[port]['observed_peer_flows']=len(v)
print(json.dumps({'ports':counts,'scope':'experiment IPv4 TCP/UDP only, snaplen96, IP/capture counters; offload and ACKs/retransmissions included, not exact Ethernet wire overhead; no payload decryption'},indent=2))
