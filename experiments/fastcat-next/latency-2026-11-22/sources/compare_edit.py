from pathlib import Path
P=Path('/Users/pizihu/Projects/FastCatAPP/core/tools/fastcat-v3-compare')
p=P/'main.go';s=p.read_text();s=s.replace('var nextTraceEnabled bool','var nextTraceEnabled bool\nvar laneDiagnostics bool')
# Extend every existing two-lane alias check without altering next-opt behavior.
s=s.replace('version == "next-primary"', '(version == "next-primary" || version == "next-latency")')
# Undo PrimaryPreferred/branch forced-primary expression for the new alias.
s=s.replace('PrimaryPreferred: (version == "next-primary" || version == "next-latency"),','PrimaryPreferred: version == "next-primary", LatencyAware: version == "next-latency", LaneTrace: laneTrace,')
s=s.replace('var trace next.Trace','var laneTrace func(next.LaneEvent)\n\t\tif laneDiagnostics { laneTrace=func(event next.LaneEvent){diagnosticMu.Lock();defer diagnosticMu.Unlock();json.NewEncoder(os.Stderr).Encode(map[string]any{"phase":"lane_event","version":version,"event":event})} }\n\t\tvar trace next.Trace',1)
s=s.replace('version != "next-primary"','version != "next-primary" && version != "next-latency"')
s=s.replace('v == "next-primary"','(v == "next-primary" || v == "next-latency")')
s=s.replace('flag.BoolVar(&nextTraceEnabled,','flag.BoolVar(&laneDiagnostics,"lane-diagnostics",false,"sanitized per-lane selection and stream timing; no packet trace")\n\tflag.BoolVar(&nextTraceEnabled,',1)
s=s.replace('type sample struct {','type sample struct {\n Lane *next.LaneObservation `json:"lane,omitempty"`',1)
s=s.replace('\trecordGatewayTLS(stream, out)','\tif laneDiagnostics { if observed,ok:=stream.(interface{LaneObservation() next.LaneObservation});ok { defer func(){o:=observed.LaneObservation();out.Lane=&o}() } }\n\trecordGatewayTLS(stream, out)',1)
p.write_text(s)
p=P/'download.go';s=p.read_text().replace('"bufio"','"bufio"\n next "core/fastcatnext"');s=s.replace('\tdefer conn.Close()','\tif laneDiagnostics {if observed,ok:=conn.(interface{LaneObservation() next.LaneObservation});ok {defer func(){row["lane"]=observed.LaneObservation()}()}}\n\tdefer conn.Close()',1);p.write_text(s)
