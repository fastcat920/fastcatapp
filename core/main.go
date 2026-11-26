//go:build !cgo

package main

import (
	"fmt"
	"os"
)

func main() {
	args := os.Args
	if len(args) == 2 && args[1] == "--supports-fcn-v3" {
		fmt.Println("fcn-v3")
		return
	}
	if len(args) <= 1 {
		fmt.Println("Arguments error")
		os.Exit(1)
	}
	startServer(args[1])
}
