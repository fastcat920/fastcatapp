package main

import (
	"encoding/json"
	"fmt"
	"strings"
)

func makePAC(hosts []string, listen string) (string, error) {
	if len(hosts) == 0 {
		return "", nil
	}
	if len(hosts) > 16 {
		return "", fmt.Errorf("PAC host limit")
	}
	normalized := make([]string, 0, len(hosts))
	for _, h := range hosts {
		name, e := publicTargetName(h + ":443")
		if e != nil {
			return "", fmt.Errorf("invalid PAC host")
		}
		normalized = append(normalized, strings.TrimSuffix(name, ":443"))
	}
	list, _ := json.Marshal(normalized)
	proxy, _ := json.Marshal("PROXY " + listen)
	return "function FindProxyForURL(url,host){var allowed=" + string(list) + ";return allowed.indexOf(host.toLowerCase())>=0?" + string(proxy) + ":\"DIRECT\";}", nil
}
