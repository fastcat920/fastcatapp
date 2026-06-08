//go:build !android && !ios && cgo

package main

func nextHandle(action *Action, result func(data interface{})) bool {
	return false
}
