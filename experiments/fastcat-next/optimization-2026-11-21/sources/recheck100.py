from lab import Lab,OUT
import time,json
with Lab('recheck100',full=True,trace=False) as lab:
 lab.start();lab.phase('post-reference100',['-download-bytes',str(100<<20),'-download-rounds','1','-download-timeout','240s','-target','191.223.214.8:19454','-target-server-name','zlhk.fastcat.ink'],'next-quic,tuic',bulk=True,timeout=550)
 (OUT/'recheck100-metadata.json').write_text(json.dumps(dict(start=lab.starttime,end=time.time(),profiles=['next-quic/quic','tuic/quic'],reason='adjacent late-stage repeat after TUIC completed 100MiB while earlier Next and v2 BBR timed out; preserve earlier failures',attempts_each=1,bytes=100<<20,deadline_seconds=240),indent=2))
print('ADJACENT RECHECK COMPLETE',flush=True)
