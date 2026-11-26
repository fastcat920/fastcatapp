"""Local owned-endpoint round trip; requires Go and openssl."""
import os, socket, subprocess, tempfile, threading, time, json, statistics, argparse
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
os.chdir(Path(__file__).parent)
def free_port():
    with socket.socket() as s:
        s.bind(('127.0.0.1',0))
        return s.getsockname()[1]
parser=argparse.ArgumentParser()
parser.add_argument('--duration',type=float,default=15)
parser.add_argument('--output',default='last-run.json')
options=parser.parse_args()
if options.duration<=0: parser.error('duration must be positive')
local, entry = free_port(), free_port()
with tempfile.TemporaryDirectory() as d:
    subprocess.run(['go','build','-o',d+'/lab','.'],check=True)
    subprocess.run(['openssl','req','-x509','-newkey','rsa:2048','-nodes','-keyout',d+'/key','-out',d+'/cert','-days','1','-subj','/CN=localhost','-addext','subjectAltName=DNS:localhost'],check=True,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
    echo=socket.create_server(('127.0.0.1',0))
    target=echo.getsockname()[1]
    def serve():
        while True:
            c,_=echo.accept()
            def handle(c):
                with c:
                    while data:=c.recv(65536): c.sendall(data)
            threading.Thread(target=handle,args=(c,),daemon=True).start()
    threading.Thread(target=serve,daemon=True).start()
    env=dict(os.environ,FASTCAT_LAB_TOKEN='local-test-token-at-least-24-bytes')
    procs=[]
    try:
        logs=tempfile.TemporaryFile()
        for args in [['-mode','server','-listen',f'127.0.0.1:{entry}','-target',f'127.0.0.1:{target}','-cert',d+'/cert','-key',d+'/key'],['-listen',f'127.0.0.1:{local}','-entry',f'localhost:{entry}','-target',f'127.0.0.1:{target}','-ca',d+'/cert']]:
            procs.append(subprocess.Popen([d+'/lab']+args,env=env,stdout=logs,stderr=logs))
        deadline = time.monotonic() + 15
        for port in (entry, local):
            while True:
                if any(p.poll() is not None for p in procs):
                    raise RuntimeError('Client or server exited during startup; inspect logs above')
                try:
                    with socket.create_connection(('127.0.0.1', port), timeout=0.2):
                        break
                except OSError:
                    if time.monotonic() >= deadline:
                        raise RuntimeError('Timed out waiting for local port %d' % port)
                    time.sleep(0.1)
        samples=[]; stop_sampling=threading.Event()
        def sample_resources():
            while not stop_sampling.is_set():
                snapshot=[]
                for p in procs:
                    result=subprocess.run(['ps','-o','rss=,%cpu=','-p',str(p.pid)],capture_output=True,text=True)
                    fields=result.stdout.split()
                    if len(fields)==2:
                        snapshot.append({'pid':p.pid,'rss_kib':int(fields[0]),'cpu_percent':float(fields[1])})
                samples.append({'elapsed_seconds':round(time.monotonic()-resource_start,3),'processes':snapshot})
                stop_sampling.wait(1)
        resource_start=time.monotonic()
        sampler=threading.Thread(target=sample_resources,daemon=True); sampler.start()
        def transfer(i):
            started=time.monotonic()
            with socket.create_connection(('127.0.0.1',local),timeout=10) as c:
                payload=os.urandom(65536); c.sendall(payload); result=b''
                while len(result)<len(payload):
                    data=c.recv(65536)
                    if not data: raise RuntimeError('early EOF')
                    result+=data
                assert result==payload
            return (time.monotonic()-started)*1000
        started=time.monotonic()
        with ThreadPoolExecutor(max_workers=16) as pool:
            latencies=list(pool.map(transfer,range(256)))
        elapsed=time.monotonic()-started
        # One connection remains established across a sustained series of exchanges.
        with socket.create_connection(('127.0.0.1',local),timeout=10) as c:
            sustained_start=time.monotonic(); rounds=0
            while time.monotonic()-sustained_start<options.duration:
                payload=os.urandom(8192); c.sendall(payload); result=b''
                while len(result)<len(payload):
                    chunk=c.recv(8192)
                    if not chunk: raise RuntimeError('sustained early EOF')
                    result+=chunk
                assert result==payload
                rounds+=1
                time.sleep(.05)
        metrics={'connections':256,'concurrency':16,'payload_bytes_each_direction':256*65536,
                 'batch_seconds':round(elapsed,3),'connection_p50_ms':round(statistics.median(latencies),3),
                 'connection_p95_ms':round(sorted(latencies)[int(len(latencies)*.95)],3),
                 'sustained_seconds':round(time.monotonic()-sustained_start,3),'sustained_rounds':rounds,
                 'sustained_payload_bytes_each_direction':rounds*8192,'payload_mismatches':0}
        stop_sampling.set(); sampler.join(timeout=5)
        metrics['resource_samples']=samples
        metrics['resource_note']='ps RSS KiB and lifetime CPU percentage; macOS loopback only'
        Path(options.output).write_text(json.dumps(metrics,indent=2)+'\n')
        print('PASS '+json.dumps({k:v for k,v in metrics.items() if k!='resource_samples'}))
    finally:
        if 'stop_sampling' in locals():
            stop_sampling.set(); sampler.join(timeout=5)
        for p in procs: p.terminate()
        for p in procs: p.wait()
        # Daemon echo listener is reclaimed when this isolated harness exits.
