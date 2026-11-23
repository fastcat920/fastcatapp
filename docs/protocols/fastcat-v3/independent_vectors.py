"""Deterministic public fixtures for the independent-stream profile; not deployment keys."""
import hashlib,hmac,json,struct
from pathlib import Path

def extract(salt,material):return hmac.new(salt,material,hashlib.sha256).digest()
def expand(key,label,size):
 out=block=b''
 for index in range(1,(size+31)//32+1):
  block=hmac.new(key,block+label.encode()+bytes([index]),hashlib.sha256).digest();out+=block
 return out[:size]
ctx=bytes(range(32));client_seed=bytes(range(32,64));server_seed=bytes(range(64,96))
client_secret=extract(ctx,client_seed);server_secret=extract(ctx,server_seed)
root=expand(extract(ctx,client_secret+server_secret),'FastCat independent/v1/session',32)
sid=bytes(range(16));binding=bytes(range(96,128));counter=7;mode=1;target=b'example.com:443'
prefix=b'FCI1'+sid+struct.pack('!QB H',counter,mode,len(target))+target
mac=hmac.new(root,b'FastCat independent/v1/flow'+prefix+binding,hashlib.sha256).digest()
stream_ctx=hashlib.sha256(b'FastCat independent/v1/stream'+prefix+binding).digest()
seeds=expand(extract(stream_ctx,root),'FastCat independent/v1/traffic',64)
values=dict(context=ctx,client_seed=client_seed,server_seed=server_seed,root=root,sid=sid,binding=binding,prefix=prefix+mac,stream_context=stream_ctx,client_traffic_secret=extract(stream_ctx,seeds[:32]),server_traffic_secret=extract(stream_ctx,seeds[32:]))
print(json.dumps({k:v.hex() for k,v in values.items()},indent=2))
