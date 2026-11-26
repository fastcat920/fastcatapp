from lab import Lab,OUT
import json
with Lab('diagnosis',trace=True) as lab:
 lab.start();lab.monitor_tcp()
 fixed=['-target','191.223.214.8:19454','-target-server-name','zlhk.fastcat.ink']
 lab.phase('diagnosis-cold',['-samples','8','-pools','1','-batches','1','-workers','1','-trace-next']+fixed,'next-h2,next-quic')
 lab.phase('diagnosis-10m',['-download-bytes',str(10<<20),'-download-rounds','2','-download-timeout','90s','-trace-next']+fixed,'next-h2,v2',bulk=True,timeout=600)
