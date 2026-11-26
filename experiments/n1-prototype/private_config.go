package main

import (
	"errors"
	"io"
	"os"
	"syscall"
)

func readPrivateConfig(path string) ([]byte, error) {
	fd, e := syscall.Open(path, syscall.O_RDONLY|syscall.O_NOFOLLOW|syscall.O_NONBLOCK, 0)
	if e != nil {
		return nil, errors.New("private config open failed")
	}
	f := os.NewFile(uintptr(fd), path)
	defer f.Close()
	st, e := f.Stat()
	if e != nil || !st.Mode().IsRegular() || st.Mode().Perm()&0077 != 0 {
		return nil, errors.New("config requires owner-only regular file")
	}
	if raw, ok := st.Sys().(*syscall.Stat_t); !ok || raw.Uid != uint32(os.Geteuid()) {
		return nil, errors.New("config owner mismatch")
	}
	b, e := io.ReadAll(io.LimitReader(f, 16385))
	if e != nil || len(b) > 16384 {
		return nil, errors.New("config read or size invalid")
	}
	return b, nil
}
