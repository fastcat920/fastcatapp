#!/usr/bin/env python3
import subprocess,re,json,time,sys
ADB=['adb','-s','A3GMVB2110006859','shell']
def state():
 s=subprocess.check_output(ADB+['dumpsys','connectivity'],text=True)
 m=re.search(r'Active default network:\s*(\d+)',s);active=m.group(1) if m else None
 line=next((x for x in s.splitlines() if active and 'NetworkAgentInfo{network{'+active+'}' in x),'')
 return dict(transport='cellular' if 'Transports: CELLULAR' in line else 'wifi' if 'Transports: WIFI' in line else 'unknown',validated='&IS_VALIDATED' in line or '&VALIDATED' in line or 'NOT_VPN&VALIDATED' in line,sim=subprocess.check_output(ADB+['getprop','gsm.sim.state'],text=True).strip())
if __name__=='__main__':
 if len(sys.argv)>1:
  want=sys.argv[1];assert want in ['wifi','cellular']
  subprocess.run(ADB+['svc','wifi','enable' if want=='wifi' else 'disable'],check=True)
  for i in range(35):
   current=state()
   if current['transport']==want and current['validated']:break
   time.sleep(1)
  else:raise SystemExit('requested validated transport unavailable: '+json.dumps(current))
 print(json.dumps(state()))
