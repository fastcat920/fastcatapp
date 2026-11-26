from pathlib import Path
P=Path('/Users/pizihu/Projects/FastCatAPP/core')
p=P/'fastcatnext/config.go';s=p.read_text().replace('LatencyAware bool','LatencyAware bool\n\t// ReserveInteractive groups the first two concurrent unknown opens briefly,\n\t// leaving an independent lane available for later work. Never classifies payload.\n\tReserveInteractive bool\n\t// ScheduleHysteresis bounds score-driven switching and consecutive assignments.\n\tScheduleHysteresis bool');s=s.replace('if c.PrimaryPreferred && c.LatencyAware {','if (c.ReserveInteractive || c.ScheduleHysteresis) && !c.LatencyAware { return ErrProtocol }\n\tif c.PrimaryPreferred && c.LatencyAware {');p.write_text(s)
p=P/'fastcatnext/client.go';s=p.read_text().replace('laneSequence    uint64','laneSequence    uint64\n\tlastLane int\n\tlaneStreak int\n\tlaneSwitchAt time.Time');assert 'laneSwitchAt' in s
s=s.replace('childConfig.LatencyAware = false','childConfig.LatencyAware = false\n\t\tchildConfig.ReserveInteractive = false\n\t\tchildConfig.ScheduleHysteresis = false');s=s.replace('c.probeWindow = time.Time{}','c.laneStreak=0\n\tc.laneSwitchAt=time.Time{}\n\tc.probeWindow = time.Time{}',1);p.write_text(s)
p=P/'fastcatnext/lanes.go';s=p.read_text().replace('if observed {\n\t\tmetric.latency.opening.Add(1)','if observed {\n\t\tmetric.latency.assignedAt = time.Now()\n\t\tmetric.latency.opening.Add(1)');p.write_text(s)
p=P/'fastcatnext/latency.go';s=p.read_text().replace('type laneLatency struct {','type laneLatency struct {\n\tassignedAt time.Time // parent Client.mu\n');s=s.replace('policy = "latency"','policy = "latency"\n\t\tif c.cfg.ReserveInteractive { policy="reserve" }');s=s.replace('other := 1 - i\n\tif c.laneActive', '''i=c.refineLatencyLocked(i,s,now)
 other := 1 - i
 if c.laneActive''')
s+='''
// Cold requests have unknown payload sizes. At most the first two in-flight
// opens share startup affinity, for <=250ms, and only while the sibling is ready
// and has a comparable path. Later traffic is free to use either lane.
func (c *Client) refineLatencyLocked(best int,s [2]LaneState,now time.Time) int {
 preferred:=best
 if c.cfg.ReserveInteractive && s[0].Ready && s[1].Ready {
  if s[0].Active+s[1].Active==1 {
   busy:=0;if s[1].Active==1 {busy=1};other:=1-busy
   age:=now.Sub(c.laneMetrics[busy].latency.assignedAt)
   if s[busy].Opening==1 && s[busy].Heavy==0 && age>=0 && age<=250*time.Millisecond && comparablePath(s[busy],s[other]) {preferred=busy}
  }
  // Prefer the lane with no established bulk flow only if its observed path is
  // comparable. This is an admission preference, never a bandwidth reservation.
  if s[0].Heavy+s[1].Heavy>0 && (s[0].Heavy==0 || s[1].Heavy==0) {
   light:=0;if s[0].Heavy>0 {light=1};other:=1-light
   if s[light].Opening<=1 && comparablePath(s[light],s[other]) {preferred=light}
  }
 }
 if c.cfg.ScheduleHysteresis && c.laneStreak>0 && s[0].Ready && s[1].Ready {
  prev:=c.lastLane
  // Never override an explicit reserve preference or hold a substantially worse lane.
  if preferred==best && preferred!=prev && now.Sub(c.laneSwitchAt)<200*time.Millisecond && c.laneStreak<3 && s[prev].ScoreUS*100<=s[preferred].ScoreUS*115 {preferred=prev}
  other:=1-preferred
  if preferred==prev && c.laneStreak>=3 && s[other].ScoreUS*100<=s[preferred].ScoreUS*125 {preferred=other}
 }
 if c.laneStreak==0 || preferred!=c.lastLane {c.lastLane=preferred;c.laneStreak=1;c.laneSwitchAt=now}else{c.laneStreak++}
 return preferred
}
func comparablePath(a,b LaneState) bool {
 ar,br:=a.RTTUS,b.RTTUS;if ar<=0 {ar=150000};if br<=0 {br=150000}
 if ar>br*3/2+25000 {return false}
 if a.FirstReadEWMAUS>0 && b.FirstReadEWMAUS>0 && a.FirstReadEWMAUS>b.FirstReadEWMAUS*2+100000 {return false}
 return true
}
''';p.write_text(s)
p=P/'tools/fastcat-v3-compare/main.go';s=p.read_text();s=s.replace('version == "next-latency"','(version == "next-latency" || version == "next-reserve")');s=s.replace('LatencyAware: (version == "next-latency" || version == "next-reserve"),','LatencyAware: (version == "next-latency" || version == "next-reserve"), ReserveInteractive: version=="next-reserve", ScheduleHysteresis: version=="next-reserve",');s=s.replace('version != "next-latency"','version != "next-latency" && version != "next-reserve"');s=s.replace('v == "next-latency"','(v == "next-latency" || v == "next-reserve")');p.write_text(s)
