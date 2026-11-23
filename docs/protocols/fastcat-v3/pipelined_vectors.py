"""Public mode-2 OPEN/ACK fixtures, not deployment keys. Requires cryptography."""
import hashlib,hmac,json,struct
from pathlib import Path
from cryptography.hazmat.primitives.ciphers.aead import ChaCha20Poly1305

def expand(key,label,size):
 out=block=b''
 for index in range(1,(size+31)//32+1):
  block=hmac.new(key,block+label.encode()+bytes([index]),hashlib.sha256).digest();out+=block
 return out[:size]
fixture=json.loads(Path(__file__).with_name('independent_vectors.json').read_text())
root=bytes.fromhex(fixture['root']);sid=bytes.fromhex(fixture['sid']);binding=bytes.fromhex(fixture['binding'])
target=b'example.com:443';counter=7
header=b'FCI2'+sid+struct.pack('!QBH',counter,2,len(target))
nonce=bytes(4)+struct.pack('!Q',counter)
key=expand(root,'FastCat independent/v1/fast-open',32)
prefix=header+ChaCha20Poly1305(key).encrypt(nonce,target,header+binding)
ack_key=expand(root,'FastCat independent/v1/fast-ack',32);status=b'\x00\x00'
ack=status+hmac.new(ack_key,b'FastCat independent/v1/OPEN_RESULT'+prefix+binding+status,hashlib.sha256).digest()
values=dict(root=root,sid=sid,binding=binding,prefix=prefix,ack=ack,service_id_input=sid,service_id_fast=hashlib.sha256(b'FastCat independent/v1/'+bytes([2])+sid).digest()[:16])
print(json.dumps({k:v.hex() for k,v in values.items()},indent=2))
