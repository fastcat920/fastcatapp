#!/usr/bin/env python3
"""IPv4 TCP capture health only: no addresses, bytes or payload exported."""
from pathlib import Path
import struct,json,sys

def union_size(parts):
 intervals=sorted((s,s+len(p)) for s,p in parts);total=0;end=None
 for a,b in intervals:
  if end is None or a>end:total+=b-a
  elif b>end:total+=b-end
  end=max(end or b,b)
 return total

def analyze(path,ports):
 raw=Path(path).read_bytes();endian='<' if raw[:4] in (b'\xd4\xc3\xb2\xa1',b'\x4d\x3c\xb2\xa1') else '>'
 link=struct.unpack_from(endian+'I',raw,20)[0];offset={1:14,113:16,276:20}[link]
 scale=1e9 if raw[:4] in (b'\x4d\x3c\xb2\xa1',b'\xa1\xb2\x3c\x4d') else 1e6
 pos=24;flows={};start=None
 while pos+16<=len(raw):
  sec,sub,n,_=struct.unpack_from(endian+'IIII',raw,pos);pos+=16;p=raw[pos:pos+n];pos+=n;ts=sec+sub/scale
  if start is None:start=ts
  if len(p)<offset+40 or p[offset]>>4!=4:continue
  ip=p[offset:];ihl=(ip[0]&15)*4
  if ip[9]!=6 or len(ip)<ihl+20:continue
  tcp=ip[ihl:];src,dst,seq,ack=struct.unpack_from('!HHII',tcp);flags=tcp[13];hlen=(tcp[12]>>4)*4
  if dst in ports:key=(ip[12:16],src,ip[16:20],dst);direction='client'
  elif src in ports:key=(ip[16:20],dst,ip[12:16],src);direction='server'
  else:continue
  body=tcp[hlen:];win=int.from_bytes(tcp[14:16],'big');options=tcp[20:hlen];sack=False;i=0
  while i<len(options):
   kind=options[i]
   if kind==0:break
   if kind==1:i+=1;continue
   if i+1>=len(options) or options[i+1]<2:break
   if kind==5:sack=True
   i+=options[i+1]
  f=flows.setdefault(key,dict(first=ts,port=key[3],events=[],client_parts=[],server_parts=[],interfaces=set()))
  if link==276:f['interfaces'].add(int.from_bytes(p[4:8],'big'))
  f['events'].append((ts,direction,seq,ack,len(body),flags,win,sack))
  if body:f[direction+'_parts'].append((seq,body))
 out=[]
 for f in sorted(flows.values(),key=lambda x:x['first']):
  sp=f['server_parts'];cp=f['client_parts'];base=min((s for s,p in sp),default=0)
  acked=base;sent=base;last_ack_ts=None;max_ack_gap=0;progress=[];first_sent=None
  for ts,d,seq,ack,n,flags,win,sack in f['events']:
   if d=='server' and n:
    if first_sent is None:first_sent=ts
    sent=max(sent,seq+n)
   if d=='client' and flags&16 and base<=ack<=sent+1 and ack>acked:
    if last_ack_ts is not None:max_ack_gap=max(max_ack_gap,(ts-last_ack_ts)*1000)
    acked=ack;last_ack_ts=ts
    if not progress or (ts-f['first'])*1000-progress[-1]['ms']>=500:progress.append(dict(ms=round((ts-f['first'])*1000,3),acked_server_bytes=acked-base))
  if last_ack_ts is not None:progress.append(dict(ms=round((last_ack_ts-f['first'])*1000,3),acked_server_bytes=acked-base))
  unique=union_size(sp);sentbytes=sum(len(p) for s,p in sp)
  row=dict(port=f['port'],first_packet_offset_ms=round((f['first']-start)*1000,3),capture_duration_ms=round((f['events'][-1][0]-f['first'])*1000,3),server_payload_unique_bytes=unique,server_payload_bytes_with_repeats=sentbytes,server_repeated_sequence_bytes=sentbytes-unique,client_repeated_sequence_bytes=sum(len(p) for s,p in cp)-union_size(cp),server_bytes_acked=min(unique,max(0,acked-base)),client_zero_window_packets=sum(d=='client' and w==0 and bool(flags&16) for ts,d,seq,ack,n,flags,w,sack in f['events']),client_sack_packets=sum(d=='client' and sack for ts,d,seq,ack,n,flags,w,sack in f['events']),rst_packets=sum(bool(flags&4) for ts,d,seq,ack,n,flags,w,sack in f['events']),max_advancing_ack_gap_ms=round(max_ack_gap,3),capture_interfaces=len(f['interfaces']),ack_progress=progress)
  out.append(row)
 return dict(flows=out,scope='Sender-side duplicate sequence/SACK/ACK/window observations; does not by itself locate physical loss or explain a censor action')
if __name__=='__main__':print(json.dumps(analyze(sys.argv[1],set(map(int,sys.argv[2:])) or {18461}),indent=2))
