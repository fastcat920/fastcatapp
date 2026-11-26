import socketserver,ssl,threading
ctx=ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
ctx.minimum_version=ssl.TLSVersion.TLSv1_3
ctx.load_cert_chain('/run/fc-trio-cert/fullchain.pem','/run/fc-trio-cert/privkey.pem')
class Echo(socketserver.BaseRequestHandler):
 def handle(self):
  self.request.settimeout(60)
  with ctx.wrap_socket(self.request,server_side=True) as c:
   while True:
    b=c.recv(65536)
    if not b:break
    c.sendall(b)
class Web(socketserver.BaseRequestHandler):
 def handle(self):
  self.request.settimeout(40)
  with ctx.wrap_socket(self.request,server_side=True) as c:
   request=b''
   while b'\r\n\r\n' not in request and len(request)<16384:
    b=c.recv(4096)
    if not b:return
    request+=b
   fields=request.split(b'\r\n',1)[0].split()
   if len(fields)<2:return
   size=0
   if fields[0]==b'GET' and fields[1].startswith(b'/bytes/'):
    try:size=min(max(int(fields[1].split(b'/')[-1]),0),134217728)
    except ValueError:pass
   c.sendall(b'HTTP/1.1 200 OK\r\nContent-Length: '+str(size).encode()+b'\r\nConnection: close\r\nCache-Control: no-store\r\n\r\n')
   block=bytes(range(4))*8192
   while size:
    b=block[:min(size,len(block))];c.sendall(b);size-=len(b)
class S(socketserver.ThreadingTCPServer):
 allow_reuse_address=True
 daemon_threads=True
for port,handler in [(19445,Echo),(19454,Web)]:
 server=S(('0.0.0.0',port),handler)
 threading.Thread(target=server.serve_forever,daemon=True).start()
class Plain(socketserver.BaseRequestHandler):
 def handle(self):
  while True:
   b=self.request.recv(65536)
   if not b:break
   self.request.sendall(b)
class UDP(socketserver.BaseRequestHandler):
 def handle(self):
  b,s=self.request;s.sendto(b,self.client_address)
server=S(('0.0.0.0',19457),Plain);threading.Thread(target=server.serve_forever,daemon=True).start()
udp=socketserver.ThreadingUDPServer(('0.0.0.0',19456),UDP);threading.Thread(target=udp.serve_forever,daemon=True).start()
threading.Event().wait()
