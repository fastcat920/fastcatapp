from lab import Lab,OUT
import subprocess as sp,time,json
while sp.run(['ps','-p','34562','-o','command='],capture_output=True,text=True).stdout.strip().endswith('/tmp/fc-next-opt/full.py'):time.sleep(2)
if not (OUT/'metadata.json').exists():raise RuntimeError('Main test failed; reference not started')
with Lab('reference100',full=True,trace=False) as lab:
 lab.start();lab.phase('downloads100m-reference',['-download-bytes',str(100<<20),'-download-rounds','1','-download-timeout','240s','-target','191.223.214.8:19454','-target-server-name','zlhk.fastcat.ink'],'vless-vision,tuic',bulk=True,timeout=550)
 (OUT/'reference100-metadata.json').write_text(json.dumps(dict(start=lab.starttime,end=time.time(),profiles=['vless-vision/tcp-tls','tuic/quic'],bytes=100<<20,deadline_seconds=240,attempts_each=1,reason='both Next H2 and v2 BBR had long-transfer timeouts; late-stage TCP and native QUIC references, not merged into earlier samples'),indent=2))
print('REFERENCE COMPLETE',flush=True)
