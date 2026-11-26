#!/usr/bin/env python3
"""Temporary bounded TLS-transparent lab gate, fixed loopback upstream only."""
import socket,threading,argparse,json,time
p=argparse.ArgumentParser();p.add_argument('--port',type=int,required=True);args=p.parse_args();assert args.port in [18469,18470]
lock=threading.Lock();limit=threading.BoundedSemaphore(8);count=0
s=socket.socket();s.setsockopt(socket.SOL_SOCKET,socket.SO_REUSEADDR,1);s.bind(('0.0.0.0',args.port));s.listen(8)
def handle(c,index):
 u=None
 try:
  drop=index%2==1
  print(json.dumps(dict(index=index,drop_before_upstream=drop)),flush=True)
  if drop:return
  u=socket.create_connection(('127.0.0.1',18466),timeout=5);c.settimeout(30);u.settimeout(30)
  def copy(a,b):
   try:
    while True:
     data=a.recv(32768)
     if not data:break
     b.sendall(data)
   except OSError:pass
   finally:
    try:b.shutdown(socket.SHUT_WR)
    except OSError:pass
  t=threading.Thread(target=copy,args=(c,u));t.start();copy(u,c);t.join(31)
 finally:
  c.close()
  if u:u.close()
  limit.release()
while True:
 c,_=s.accept()
 if not limit.acquire(blocking=False):c.close();continue
 with lock:count+=1;index=count
 threading.Thread(target=handle,args=(c,index),daemon=True).start()
