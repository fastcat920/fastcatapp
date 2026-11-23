package fastcatentry

import (
	"errors"
	"strconv"
)

type StatusError int

func (s StatusError) Error() string { return "proxy CONNECT returned HTTP " + strconv.Itoa(int(s)) }

var ErrProtocol = errors.New("gateway protocol negotiation failed")
var ErrTarget = errors.New("target resolution failed")

// ErrUnresponsive requires an independent gateway-only exchange to have timed out.
var ErrUnresponsive = errors.New("established HTTP/3 gateway did not answer a liveness check")
