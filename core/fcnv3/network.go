package fcnv3

import (
	"errors"
	"net"
)

var ErrNetworkChanged = errors.New("FCN v3 network generation changed")

// UpdateNetwork receives the active network identity from the caller. A new
// identity invalidates the old socket and pending handshake. New traffic then
// uses a fresh socket on the new network. Existing streams and associations
// are closed and never replayed. Call it once to register the initial network.
func (c *Client) UpdateNetwork(id string) error {
	if len(id) == 0 || len(id) > 128 {
		return errors.New("invalid FCN v3 network identity")
	}
	c.mu.Lock()
	if c.ctx.Err() != nil {
		c.mu.Unlock()
		return net.ErrClosed
	}
	if c.network == "" || c.network == id {
		c.network = id
		c.mu.Unlock()
		return nil
	}
	c.network = id
	c.refreshEntry = c.cfg.EntryDNS != nil
	if resolver, ok := c.cfg.EntryDNS.(interface{ ResetNetwork() }); ok {
		resolver.ResetNetwork()
	}
	old := c.current
	c.current = nil
	if a := c.pending; a != nil {
		c.pending = nil
		a.cancel()
	}
	c.mu.Unlock()
	if old != nil {
		old.quic.CloseWithError(0, "")
	}
	return nil
}
