#!/usr/bin/env python3
from pathlib import Path
import subprocess,json,time,sys
from phone_network import state
from phone_proxy import apply,restore,cmd
root=Path(__file__).resolve().parent/'results/phase10-2026-11-24'
label=sys.argv[1];mode=sys.argv[2];assert label in ['wifi-direct','wifi-proxy','cellular-direct','cellular-proxy'];assert mode in ['none','pac','manual']
network=label.split('-')[0];before=state();assert before['transport']==network and before['validated'],before
stamp=time.time();token=Path('/tmp/fastcat-n1-private/phase10-browser.token').read_text().strip();url='https://zlhk.fastcat.ink:18472/lab/'+token+'/'+label
original_mobile=cmd(['settings','get','global','mobile_data']).strip();received=None
try:
 if network=='wifi' and mode=='manual':cmd(['svc','data','disable'])
 apply(mode)
 for a in [['input','keyevent','KEYCODE_WAKEUP'],['am','force-stop','com.honor.browser'],['am','start','-a','android.intent.action.VIEW','-d',url,'-p','com.honor.browser']]:cmd(a)
 for i in range(24):
  time.sleep(4)
  r=subprocess.run(['ssh','-o','BatchMode=yes','-o','ConnectTimeout=8','-S','/tmp/n1-phase9-ssh.sock','root@zlhk.fastcat.ink',"journalctl -u fastcat-n1-phase10-web -o cat --no-pager | sed -n '/BROWSER_RESULT/p'"],capture_output=True,text=True,timeout=20)
  for line in r.stdout.splitlines():
   if 'BROWSER_RESULT ' not in line:continue
   item=json.loads(line.split('BROWSER_RESULT ',1)[1])
   if item['report']['label']==label and item['unix']/1000>=stamp-2:received=item;break
  if received:break
finally:
 settings_restored=restore()
 if original_mobile=='1':cmd(['svc','data','enable'])
record=dict(label=label,mode=mode,start_unix=stamp,network_before=before,network_after=state(),settings_restored=settings_restored,result=received)
file=root/(label+'-'+mode+'-trial.json');file.write_text(json.dumps(record,indent=2))
print(json.dumps(dict(label=label,mode=mode,received=received is not None,via_node=received['via_node'] if received else None,passed=sum(x['ok'] for x in received['report']['rows']) if received else 0,settings_restored=settings_restored)))
