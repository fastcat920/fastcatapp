package fastcatnext

import (
	"context"
	"net"
	"sync"
)

// Assign each new stream once. Existing streams stay on their connection;
// neither a failure nor a change in load replays application bytes.
func (c *Client) dialLane(ctx context.Context, target string) (net.Conn, error) {
	c.mu.Lock()
	if c.closed {
		c.mu.Unlock()
		return nil, net.ErrClosed
	}
	i := 0
	for j := 1; j < len(c.lanes); j++ {
		if c.laneActive[j] < c.laneActive[i] {
			i = j
		}
	}
	c.laneActive[i]++
	c.mu.Unlock()
	release := func() {
		c.mu.Lock()
		c.laneActive[i]--
		c.mu.Unlock()
	}
	n, err := c.lanes[i].Dial(ctx, target)
	if err != nil {
		release()
		return nil, err
	}
	return &laneConn{Conn: n, release: release}, nil
}

type laneConn struct {
	net.Conn
	once    sync.Once
	release func()
}

func (c *laneConn) Close() error {
	err := c.Conn.Close()
	c.once.Do(c.release)
	return err
}

func (c *laneConn) CloseWrite() error {
	return c.Conn.(interface{ CloseWrite() error }).CloseWrite()
}
