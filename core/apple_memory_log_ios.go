//go:build ios && cgo

package main

/*
#include <stdlib.h>
#include <os/log.h>
static void fastcat_memory_log(const char *message) {
    os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_DEFAULT, "%{public}s", message);
}
*/
import "C"
import "unsafe"

func init() {
	appleMemoryStageSink = func(message string) {
		text := C.CString(message)
		defer C.free(unsafe.Pointer(text))
		C.fastcat_memory_log(text)
	}
}
