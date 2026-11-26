"""Isolated failure-stage checks; does not use demonstration ports."""
import os, socket, subprocess, tempfile, time, threading
from pathlib import Path
os.chdir(Path(__file__).parent)
TOKEN = 'local-test-token-at-least-24-bytes'
def port():
    with socket.socket() as s:
        s.bind(('127.0.0.1', 0))
        return s.getsockname()[1]
with tempfile.TemporaryDirectory() as d:
    subprocess.run(['go','build','-o',d+'/lab','.'],check=True)
    subprocess.run(['openssl','req','-x509','-newkey','rsa:2048','-nodes','-keyout',d+'/key','-out',d+'/cert','-days','1','-subj','/CN=localhost','-addext','subjectAltName=DNS:localhost'],check=True,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
    for name, expected in [('entry_down','stage=entry_tcp error='), ('wrong_ca','stage=tls error='), ('wrong_token','status=403'), ('target_down','status=502'), ('half_close','stage=tunnel elapsed=')]:
        entry, local, target = port(), port(), port()
        procs=[]; files=[]; listener=None
        if name=='half_close':
            listener=socket.create_server(('127.0.0.1',target))
            def reply_after_eof():
                for _ in range(2):
                    c,_=listener.accept()
                    with c:
                        c.settimeout(8)
                        data=b''
                        while True:
                            chunk=c.recv(65536)
                            if not chunk: break
                            data+=chunk
                        c.sendall(data)
            threading.Thread(target=reply_after_eof,daemon=True).start()
        def start(args, token=TOKEN):
            f=tempfile.TemporaryFile(mode='w+'); files.append(f)
            p=subprocess.Popen([d+'/lab']+args,env=dict(os.environ,FASTCAT_LAB_TOKEN=token),stdout=f,stderr=f)
            procs.append(p); return p,f
        def ready(p, n):
            end=time.monotonic()+15
            while time.monotonic()<end:
                if p.poll() is not None: raise RuntimeError('process exited')
                try:
                    with socket.create_connection(('127.0.0.1',n),timeout=.1): return
                except OSError: time.sleep(.05)
            raise RuntimeError('startup timeout')
        try:
            if name!='entry_down':
                server_args=['-mode','server','-listen',f'127.0.0.1:{entry}','-target',f'127.0.0.1:{target}','-cert',d+'/cert','-key',d+'/key']
                p,serverlog=start(['-mode','server','-listen',f'127.0.0.1:{entry}','-target',f'127.0.0.1:{target}','-cert',d+'/cert','-key',d+'/key'])
                ready(p,entry)
                server_process=p
            args=['-listen',f'127.0.0.1:{local}','-entry',f'localhost:{entry}','-target',f'127.0.0.1:{target}']
            if name!='wrong_ca': args+=['-ca',d+'/cert']
            p,clientlog=start(args, 'incorrect-token-at-least-24-bytes' if name=='wrong_token' else TOKEN)
            if name=='half_close':
                for attempt in range(2):
                    if attempt:
                        server_process.terminate(); server_process.wait()
                        server_process,serverlog=start(server_args)
                        ready(server_process,entry)
                    # Use the readiness connection as the actual test connection.
                    end=time.monotonic()+15
                    while True:
                        try:
                            connection=socket.create_connection(('127.0.0.1',local),timeout=8); break
                        except OSError:
                            if time.monotonic()>end: raise
                            time.sleep(.05)
                    with connection as c:
                        payload=os.urandom(65536); c.sendall(payload); c.shutdown(socket.SHUT_WR)
                        result=b''
                        while True:
                            chunk=c.recv(65536)
                            if not chunk: break
                            result+=chunk
                        assert result==payload, 'half-close payload mismatch'
                print('PASS server_restart_new_connection payload verified')
            else:
                ready(p,local)
            end=time.monotonic()+12
            while time.monotonic()<end:
                clientlog.seek(0); logs=clientlog.read()
                if expected in logs: break
                time.sleep(.05)
            else: raise AssertionError(name+': '+logs)
            if name in ('wrong_token','target_down'):
                serverlog.seek(0); serverlogs=serverlog.read()
                assert ('stage=authentication rejected' if name=='wrong_token' else 'stage=target_tcp error=') in serverlogs
            assert TOKEN not in logs
            print('PASS',name,expected)
        finally:
            for p in procs: p.terminate()
            for p in procs: p.wait()
            for f in files: f.close()
            if listener: listener.close()
