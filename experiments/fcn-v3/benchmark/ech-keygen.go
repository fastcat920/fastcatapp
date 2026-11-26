//go:build ignore

// Build this lab utility explicitly in the core module. Secret PEM is stored in
// a newly created owner-only file. Only the public ECHConfigList goes to stdout.
package main

import (
	"fmt"
	"log"
	"os"

	"github.com/metacubex/mihomo/component/ech"
)

func main() {
	if len(os.Args) != 3 {
		log.Fatal("usage: ech-keygen public-name new-keys-file")
	}
	list, keys, err := ech.GenECHConfig(os.Args[1])
	if err != nil {
		log.Fatal(err)
	}
	file, err := os.OpenFile(os.Args[2], os.O_WRONLY|os.O_CREATE|os.O_EXCL, 0600)
	if err != nil {
		log.Fatal(err)
	}
	_, err = file.WriteString(keys)
	closeErr := file.Close()
	if err != nil {
		log.Fatal(err)
	}
	if closeErr != nil {
		log.Fatal(closeErr)
	}
	fmt.Println(list)
}
