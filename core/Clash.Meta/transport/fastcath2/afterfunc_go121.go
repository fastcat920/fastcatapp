//go:build go1.21

package h2client

import "context"

var afterFunc = context.AfterFunc
