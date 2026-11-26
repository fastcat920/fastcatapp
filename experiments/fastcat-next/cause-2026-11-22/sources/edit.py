from pathlib import Path
P=Path('/Users/pizihu/Projects/FastCatAPP/core')
p=P/'fastcatnext/trace.go';s=p.read_text().replace('"context"','"context"\n"crypto/sha256"\n"encoding/hex"');s=s.replace('type Event struct {','type Event struct {\n AtUnixUS int64 `json:"at_unix_us,omitempty"`\n RequestTag string `json:"request_tag,omitempty"`\n Stream uint64 `json:"stream,omitempty"`\n PTOEvents int64 `json:"pto_events,omitempty"`\n CurrentPTO int64 `json:"current_pto,omitempty"`\n LatestRTTUS int64 `json:"latest_rtt_us,omitempty"`\n MinRTTUS int64 `json:"min_rtt_us,omitempty"`')
s=s.replace('producers                                                                                 atomic.Int64','producers                                                                                 atomic.Int64\n ptoEvents,currentPTO,latestRTT,minRTT atomic.Int64')
s=s.replace('setMax(&t.pto, int64(p.PTOCount))','n:=int64(p.PTOCount);old:=t.currentPTO.Swap(n);if n>old {t.ptoEvents.Add(n-old)}\n setMax(&t.pto, n)')
s=s.replace('if p.CongestionWindow > 0 {','if p.LatestRTT>0 { t.latestRTT.Store(p.LatestRTT.Microseconds()) };if p.MinRTT>0 {t.minRTT.Store(p.MinRTT.Microseconds())}\n if p.CongestionWindow > 0 {')
s=s.replace('return Event{WireBytesSent:', 'return Event{AtUnixUS:time.Now().UnixMicro(),PTOEvents:t.ptoEvents.Load(),CurrentPTO:t.currentPTO.Load(),LatestRTTUS:t.latestRTT.Load(),MinRTTUS:t.minRTT.Load(),WireBytesSent:')
s=s.replace('func attachServerQUICTrace(cfg *quic.Config, trace Trace) {','func attachServerQUICTrace(cfg *quic.Config, trace Trace, registries ...*sync.Map) {')
s=s.replace('go func() {\n\t\tticker := time.NewTicker(5 * time.Second)','go func() {\n\t\tticker := time.NewTicker(250 * time.Millisecond)')
s=s.replace('go func() {\n\t\t\tticker := time.NewTicker(5 * time.Second)','if len(registries)>0 {registries[0].Store(ctx,t)}\n\t\tgo func() {\n if len(registries)>0 {defer registries[0].Delete(ctx)}\n\t\t\tticker := time.NewTicker(250 * time.Millisecond)')
s=s.replace('ticker := time.NewTicker(5 * time.Second)','ticker := time.NewTicker(250 * time.Millisecond)')
s+='''
// A one-way hash of a random per-OPEN nonce joins diagnostics across ends.
// Neither the nonce itself, credentials, target nor business payload is logged.
func diagnosticTag(n [16]byte) string {h:=sha256.Sum256(n[:]);return hex.EncodeToString(h[:16])}
''';p.write_text(s)
p=P/'fastcatnext/client.go';s=p.read_text().replace('q                 *quic.Conn','q                 *quic.Conn\n stats *quicTrace');s=s.replace('stats.trace = c.cfg.Trace','p.stats=stats\n\t\t\tstats.trace = c.cfg.Trace');s=s.replace('if p.q != nil {\n\t\tstream, e := p.q.OpenStreamSync(ctx)','tag:=""\n\tif c.cfg.Trace!=nil {var nonce [16]byte;copy(nonce[:],head[len(head)-48:len(head)-32]);tag=diagnosticTag(nonce)}\n\tif p.q != nil {\n\t\tstream, e := p.q.OpenStreamSync(ctx)',1)
s=s.replace('&quicConn{Stream: stream,', '&quicConn{physical:p, traced:c.cfg.Trace!=nil, tag:tag, openedAt:time.Now().UnixMicro(), Stream: stream,')
s=s.replace('type quicConn struct {','type quicConn struct {\n physical *physical\n traced bool\n tag string\n openedAt int64\n statusStart,statusEnd,firstData,readWait,writeWait atomic.Int64')
s=s.replace('func (c *quicConn) Write(b []byte) (int, error) {','func (c *quicConn) Write(b []byte) (int, error) {\n if c.traced {start:=time.Now();defer func(){c.writeWait.Add(time.Since(start).Microseconds())}()}')
s=s.replace('func (c *quicConn) Read(b []byte) (int, error) {','func (c *quicConn) Read(b []byte) (int, error) {\n if c.traced {start:=time.Now();defer func(){c.readWait.Add(time.Since(start).Microseconds())}()}')
s=s.replace('c.once.Do(func() {\n\t\tvar status [1]byte','c.once.Do(func() {\n if c.traced {c.statusStart.Store(time.Now().UnixMicro());defer func(){c.statusEnd.Store(time.Now().UnixMicro())}()}\n\t\tvar status [1]byte')
s=s.replace('return c.Stream.Read(b)\n}', 'n,e:=c.Stream.Read(b);if c.traced && n>0 {c.firstData.CompareAndSwap(0,time.Now().UnixMicro())};return n,e\n}',1);p.write_text(s)
p=P/'fastcatnext/server.go';s=p.read_text().replace('cfg   ServerConfig','cfg   ServerConfig\n traceSessions sync.Map');s=s.replace('attachServerQUICTrace(qc, s.cfg.Trace)','attachServerQUICTrace(qc, s.cfg.Trace, &s.traceSessions)');needle='ctx, stop := context.WithTimeout(c.Context(), 10*time.Minute)';s=s.replace(needle,'''trace:=s.cfg.Trace
 if trace!=nil {tag:=diagnosticTag(h.Nonce);var session uint64;if t,ok:=s.traceSessions.Load(c.Context());ok {session=t.(*quicTrace).session};base:=trace;trace=func(e Event){e.AtUnixUS=time.Now().UnixMicro();e.RequestTag=tag;e.Stream=uint64(stream.StreamID());e.Session=session;base(e)};trace(Event{Stage:"server_open_received",Carrier:"quic",OK:true})}
 '''+needle)
s=s.replace('target, e := s.cfg.dial(dialctx, network, h.Target)\n\tcancel()', 'dialStart:=time.Now()\n target, e := s.cfg.dial(dialctx, network, h.Target)\n if trace!=nil {trace(Event{Stage:"server_target_dial",Carrier:"quic",DurationUS:time.Since(dialStart).Microseconds(),OK:e==nil})}\n\tcancel()',1 if False else 0) if False else s
# Restrict replacements to QUIC stream handler.
i=s.index('func (s *Server) serveStream');a,b=s[:i],s[i:]
b=b.replace('target, e := s.cfg.dial(dialctx, network, h.Target)','dialStart:=time.Now()\n target, e := s.cfg.dial(dialctx, network, h.Target)\n if trace!=nil {trace(Event{Stage:"server_target_dial",Carrier:"quic",DurationUS:time.Since(dialStart).Microseconds(),OK:e==nil})}',1)
b=b.replace('done := context.AfterFunc(ctx,','if trace!=nil {trace(Event{Stage:"server_ack_queued",Carrier:"quic",OK:true})}\n done := context.AfterFunc(ctx,',1)
b=b.replace('s.cfg.Trace, "quic",','trace, "quic",');s=a+b;p.write_text(s)
