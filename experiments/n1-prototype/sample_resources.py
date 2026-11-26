#!/usr/bin/env python3
"""Run on lab server; bounded numeric process/TCP resource samples only."""
import argparse,json,os,re,subprocess,time
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--pid',type=int,required=True);p.add_argument('--port',type=int,required=True);p.add_argument('--seconds',type=int,default=900);p.add_argument('--output',required=True);args=p.parse_args()
fd=os.open(args.output,os.O_WRONLY|os.O_CREAT|os.O_EXCL,0o600)
start=time.monotonic()
with os.fdopen(fd,'w') as out:
 while time.monotonic()-start<min(args.seconds,1800):
  try:
   status=Path(f'/proc/{args.pid}/status').read_text();stat=Path(f'/proc/{args.pid}/stat').read_text().split(') ',1)[1].split()
   value=lambda key:int(re.search(r'^'+key+r':\s+(\d+)',status,re.M).group(1))
   ss=subprocess.run(['ss','-tinH',f'( sport = :{args.port} )'],capture_output=True,text=True,timeout=2).stdout
   tcp=[]
   for line in ss.splitlines():
    if 'cwnd:' not in line:continue
    d={}
    for key in ['cwnd','rto','bytes_acked','bytes_retrans','segs_out','data_segs_out','unacked','rcv_space','snd_wnd']:
     m=re.search(r'(?:^|\s)'+key+r':(\d+)',line)
     if m:d[key]=int(m.group(1))
    m=re.search(r'rtt:([\d.]+)/([\d.]+)',line)
    if m:d['rtt_ms']=float(m.group(1));d['rttvar_ms']=float(m.group(2))
    tcp.append(d)
   row=dict(ms=round((time.monotonic()-start)*1000,2),pid=args.pid,rss_kib=value('VmRSS'),threads=value('Threads'),fds=len(os.listdir(f'/proc/{args.pid}/fd')),cpu_ticks=int(stat[11])+int(stat[12]),load1=os.getloadavg()[0],tcp=tcp)
   out.write(json.dumps(row)+'\n');out.flush()
  except FileNotFoundError:break
  time.sleep(.5)
