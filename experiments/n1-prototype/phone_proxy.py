#!/usr/bin/env python3
"""Scoped Android global proxy controls; original values remain private."""
from pathlib import Path
import json,subprocess,shlex,time,sys
BASE=['adb','-s','A3GMVB2110006859','shell']
ORIGINAL=Path('/tmp/fastcat-n1-private/phase10-original-proxy.json')
def cmd(parts):return subprocess.run(BASE+[' '.join(shlex.quote(str(x)) for x in parts)],capture_output=True,text=True,check=True).stdout

def put(k,v):cmd(['settings','put','global',k,v])
def clear():
 put('http_proxy',':0');time.sleep(1)
 for k,v in [('global_http_proxy_host',''),('global_http_proxy_port','0'),('global_http_proxy_exclusion_list',''),('global_proxy_pac_url','')]:put(k,v)
def restore():
 clear()
 for k,v in json.loads(ORIGINAL.read_text()).items():
  if v=='null':cmd(['settings','delete','global',k])
  else:put(k,v)
 time.sleep(1)
 actual={k:cmd(['settings','get','global',k]).strip() for k in json.loads(ORIGINAL.read_text())}
 return actual==json.loads(ORIGINAL.read_text())

def apply(mode):
 assert mode in ['none','pac','manual'];clear()
 if mode=='pac':put('global_proxy_pac_url','http://127.0.0.1:18091/proxy.pac')
 if mode=='manual':put('http_proxy','127.0.0.1:18091')
 time.sleep(2)
if __name__=='__main__':
 if sys.argv[1]=='restore':print(json.dumps({'settings_restored':restore()}))
 else:apply(sys.argv[1]);print(json.dumps({'proxy_mode':sys.argv[1]}))
