package tun

import "sync"

var borrowedDescriptors sync.Map

// BorrowFileDescriptor retains caller ownership even on construction errors.
// NativeTun duplicates the descriptor when it actually adopts it.
func BorrowFileDescriptor(fd int) func() {
	token := new(byte)
	borrowedDescriptors.Store(fd, token)
	return func() { borrowedDescriptors.CompareAndDelete(fd, token) }
}
