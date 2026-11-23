package fcn

import "time"

type TransportObservation struct {
	WireBytesSent        uint64 `json:"wire_bytes_sent,omitempty"`
	WireBytesReceived    uint64 `json:"wire_bytes_received,omitempty"`
	PrefixReceivedBytes  int64  `json:"prefix_received_bytes,omitempty"`
	PrefixDeliveredBytes int64  `json:"prefix_delivered_bytes,omitempty"`
	GSO                  bool   `json:"gso"`
	AtUnixUS             int64  `json:"at_unix_us"`
	Session              uint64 `json:"session"`
	RequestTag           string `json:"request_tag,omitempty"`
	Stream               uint64 `json:"stream"`
	OpenedAtUS           int64  `json:"opened_at_us"`
	StatusStartUS        int64  `json:"status_start_us"`
	StatusEndUS          int64  `json:"status_end_us"`
	FirstDataUS          int64  `json:"first_data_us"`
	StatusWaitUS         int64  `json:"status_wait_us"`
	ReadWaitUS           int64  `json:"read_wait_us"`
	WriteWaitUS          int64  `json:"write_wait_us"`
	PacketsLost          uint64 `json:"packets_lost"`
	PacketsSent          uint64 `json:"packets_sent"`
	PacketsReceived      uint64 `json:"packets_received"`
	RTTUS                int64  `json:"rtt_us"`
	Counters             *Event `json:"counters,omitempty"`
}

func (c *quicConn) TransportObservation() TransportObservation {
	o := TransportObservation{AtUnixUS: time.Now().UnixMicro(), RequestTag: c.tag, Stream: uint64(c.StreamID()), OpenedAtUS: c.openedAt, StatusStartUS: c.statusStart.Load(), StatusEndUS: c.statusEnd.Load(), FirstDataUS: c.firstData.Load(), ReadWaitUS: c.readWait.Load(), WriteWaitUS: c.writeWait.Load()}
	if c.prefix != nil {
		o.PrefixReceivedBytes = c.prefix.received.Load()
		o.PrefixDeliveredBytes = c.prefix.delivered.Load()
	}
	if o.StatusStartUS > 0 && o.StatusEndUS >= o.StatusStartUS {
		o.StatusWaitUS = o.StatusEndUS - o.StatusStartUS
	}
	if c.physical != nil {
		p := c.physical
		if p.q != nil {
			o.GSO = p.q.ConnectionState().GSO
			s := p.q.ConnectionStats()
			o.WireBytesSent = s.BytesSent
			o.WireBytesReceived = s.BytesReceived
			o.PacketsLost = s.PacketsLost
			o.PacketsSent = s.PacketsSent
			o.PacketsReceived = s.PacketsReceived
			o.RTTUS = s.SmoothedRTT.Microseconds()
		}
		if p.stats != nil {
			e := p.stats.snapshot("request_snapshot", p.stats.started, nil)
			o.Counters = &e
			o.Session = p.stats.session
		}
	}
	return o
}
func (c *laneConn) TransportObservation() TransportObservation {
	if n, ok := c.Conn.(interface{ TransportObservation() TransportObservation }); ok {
		return n.TransportObservation()
	}
	return TransportObservation{}
}
