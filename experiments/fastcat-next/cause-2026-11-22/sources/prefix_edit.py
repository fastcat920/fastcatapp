from pathlib import Path
P=Path('/Users/pizihu/Projects/FastCatAPP/core')
p=P/'fastcatnext/config.go';s=p.read_text().replace('Trace                                     Trace','Trace                                     Trace\n PrefixTrace bool').replace('Trace        Trace','Trace        Trace\n PrefixTrace bool');assert s.count('PrefixTrace')==2;p.write_text(s)
p=P/'fastcatnext/client.go';s=p.read_text().replace('p.stats = stats','stats.prefix=c.cfg.PrefixTrace\n\t\t\tp.stats = stats');p.write_text(s)
p=P/'fastcatnext/server.go';s=p.read_text().replace('attachServerQUICTrace(qc, s.cfg.Trace, &s.traceSessions)','attachServerQUICTrace(qc, s.cfg.Trace, &s.traceSessions, s.cfg.PrefixTrace)');p.write_text(s)
p=P/'fastcatnext/trace.go';s=p.read_text().replace('type Event struct {','type Event struct {\n Packet uint64 `json:"packet,omitempty"`\n PacketSpace string `json:"packet_space,omitempty"`\n FrameOffset int64 `json:"frame_offset,omitempty"`\n FrameLength int64 `json:"frame_length,omitempty"`\n MetaDropped int64 `json:"meta_dropped,omitempty"`')
s=s.replace('type quicTrace struct {','type quicTrace struct {\n prefix bool\n metaMu sync.Mutex\n interest map[tracePacket]bool\n metaEvents,metaDropped atomic.Int64')
s=s.replace('setMax(&t.pto, n)','setMax(&t.pto, n)\n if t.prefix && n>old {t.trace(t.snapshot(t.side+"_pto_raised",t.started,nil))}')
s=s.replace('case qlog.PacketSent:\n\t\tt.wireSent.Add', 'case qlog.PacketLost:\n if t.prefix {t.recordPrefixLost(p)}\n\tcase qlog.PacketSent:\n if t.prefix {t.recordPrefixFrames(p.Header,p.Frames,true)}\n\t\tt.wireSent.Add')
s=s.replace('case qlog.PacketReceived:\n\t\tt.wireReceived.Add','case qlog.PacketReceived:\n if t.prefix {t.recordPrefixFrames(p.Header,p.Frames,false)}\n\t\tt.wireReceived.Add')
s=s.replace('return Event{AtUnixUS:','return Event{MetaDropped:t.metaDropped.Load(),AtUnixUS:')
s=s.replace('func attachServerQUICTrace(cfg *quic.Config, trace Trace, registries ...*sync.Map) {','func attachServerQUICTrace(cfg *quic.Config, trace Trace, registry *sync.Map, prefix bool) {')
s=s.replace('t := &quicTrace{trace: trace,','t := &quicTrace{prefix:prefix,trace: trace,')
s=s.replace('if len(registries) > 0 {\n\t\t\tregistries[0].Store(ctx, t)\n\t\t}', 'if registry!=nil {registry.Store(ctx,t)}')
s=s.replace('if len(registries) > 0 {\n\t\t\t\tdefer registries[0].Delete(ctx)\n\t\t\t}', 'if registry!=nil {defer registry.Delete(ctx)}')
s+='''
type tracePacket struct {space string;number uint64}
func(t *quicTrace) emitMeta(e Event){if t.trace==nil{return};if t.metaEvents.Add(1)>8192 {t.metaDropped.Add(1);return};t.trace(e)}
func(t *quicTrace) recordPrefixFrames(h qlog.PacketHeader,frames []qlog.Frame,sent bool){
 for _,frame:=range frames {f,ok:=frame.Frame.(*qlog.StreamFrame);if !ok || f.Offset>=8192 || f.Length<=0 {continue}
  key:=tracePacket{string(h.PacketType),uint64(h.PacketNumber)}
  if sent {t.metaMu.Lock();if t.interest==nil {t.interest=make(map[tracePacket]bool)};if len(t.interest)<4096 {t.interest[key]=true}else{t.metaDropped.Add(1)};t.metaMu.Unlock()}
  stage:=t.side+"_stream_prefix_received";if sent {stage=t.side+"_stream_prefix_sent"}
  t.emitMeta(Event{AtUnixUS:time.Now().UnixMicro(),Session:t.session,Stage:stage,Carrier:"quic",OK:true,Stream:uint64(f.StreamID),Packet:key.number,PacketSpace:key.space,FrameOffset:f.Offset,FrameLength:f.Length})
 }
}
func(t *quicTrace) recordPrefixLost(p qlog.PacketLost){
 key:=tracePacket{string(p.Header.PacketType),uint64(p.Header.PacketNumber)};t.metaMu.Lock();interest:=t.interest[key];t.metaMu.Unlock();if interest {t.emitMeta(Event{AtUnixUS:time.Now().UnixMicro(),Session:t.session,Stage:t.side+"_stream_prefix_lost",Carrier:"quic",Packet:key.number,PacketSpace:key.space})}
}
''';p.write_text(s)
p=P/'tools/fastcat-next/main.go';s=p.read_text().replace('Trace                                          bool','Trace                                          bool\n PrefixTrace bool').replace('IdleTimeout: idle, Trace: trace,','IdleTimeout: idle, Trace: trace, PrefixTrace:cfg.PrefixTrace,');p.write_text(s)
p=P/'tools/fastcat-v3-compare/main.go';s=p.read_text().replace('var laneDiagnostics bool','var laneDiagnostics bool\nvar prefixTrace bool');s=s.replace('LaneTrace: laneTrace, AdaptiveLanes:', 'PrefixTrace:prefixTrace, LaneTrace: laneTrace, AdaptiveLanes:');s=s.replace('flag.BoolVar(&nextTraceEnabled,','flag.BoolVar(&prefixTrace,"trace-prefix",false,"bounded QUIC prefix offset and packet number metadata; no payload")\n\tflag.BoolVar(&nextTraceEnabled,',1);s=s.replace('flag.Parse()','flag.Parse()\n if prefixTrace {nextTraceEnabled=true}',1);p.write_text(s)
