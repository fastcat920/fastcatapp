import socketserver,ssl
ctx=ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
ctx.minimum_version=ssl.TLSVersion.TLSv1_3
ctx.load_cert_chain('/etc/letsencrypt/live/zlhk.fastcat.ink/fullchain.pem','/etc/letsencrypt/live/zlhk.fastcat.ink/privkey.pem')
class E(socketserver.BaseRequestHandler):
 def handle(self):
  self.request.settimeout(60)
  with ctx.wrap_socket(self.request,server_side=True) as conn:
   while True:
    b=conn.recv(65536)
    if not b:break
    conn.sendall(b)
class S(socketserver.ThreadingTCPServer):
 allow_reuse_address=True
 daemon_threads=True
S(('0.0.0.0',19445),E).serve_forever()
