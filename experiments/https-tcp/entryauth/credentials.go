// Package entryauth authenticates new CONNECT requests against reloadable device grants.
package entryauth

import (
	"bufio"
	"crypto/sha256"
	"errors"
	"fmt"
	"os"
	"strings"
	"sync"
	"sync/atomic"
)

type tokenSet map[[sha256.Size]byte]struct{}

type Store struct {
	path   string
	mu     sync.Mutex // Serialize concurrent reloads; requests only load the snapshot.
	active atomic.Pointer[tokenSet]
}

func validToken(token string) bool {
	return len(token) >= 24 && len(token) <= 512 && strings.IndexFunc(token, func(r rune) bool { return r < '!' || r > '~' }) < 0
}

func New(token, path string) (*Store, error) {
	c := &Store{path: path}
	if path != "" {
		if token != "" {
			return nil, errors.New("select either a single token or a tokens file")
		}
		if err := c.Reload(); err != nil {
			return nil, err
		}
		return c, nil
	}
	if !validToken(token) {
		return nil, errors.New("token must contain 24 to 512 visible ASCII characters")
	}
	active := tokenSet{sha256.Sum256([]byte(token)): {}}
	c.active.Store(&active)
	return c, nil
}

func (c *Store) Reload() error {
	if c.path == "" {
		return errors.New("no tokens file configured")
	}
	c.mu.Lock()
	defer c.mu.Unlock()
	f, err := os.Open(c.path)
	if err != nil {
		return fmt.Errorf("open tokens file: %w", err)
	}
	defer f.Close()
	active := make(tokenSet)
	scanner := bufio.NewScanner(f)
	for line := 1; scanner.Scan(); line++ {
		token := scanner.Text()
		if !validToken(token) {
			return fmt.Errorf("invalid token on line %d", line)
		}
		hash := sha256.Sum256([]byte(token))
		if _, exists := active[hash]; exists {
			return fmt.Errorf("duplicate token on line %d", line)
		}
		active[hash] = struct{}{}
	}
	if err := scanner.Err(); err != nil {
		return fmt.Errorf("read tokens file: %w", err)
	}
	// Publish only after all lines are valid. An empty file revokes all tokens.
	c.active.Store(&active)
	return nil
}

func (c *Store) Authorized(values []string) bool {
	if len(values) != 1 {
		return false
	}
	scheme, token, ok := strings.Cut(values[0], " ")
	if !ok || !strings.EqualFold(scheme, "Bearer") || !validToken(token) {
		return false
	}
	_, present := (*c.active.Load())[sha256.Sum256([]byte(token))]
	return present
}
