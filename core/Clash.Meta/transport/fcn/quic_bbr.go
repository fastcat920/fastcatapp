package fcn

import "github.com/metacubex/quic-go"

// ApplyQUICBBR applies the default FCN congestion controller to a QUIC connection.
func ApplyQUICBBR(conn *quic.Conn) {
	setProfileCC(conn, "bbr", "")
}
