package main

import (
	"bufio"
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"time"

	"github.com/fastcat920/fcnv3"
)

type networkCommand struct {
	Network    string `json:"network"`
	TCP        int    `json:"tcp"`
	UDP        int    `json:"udp"`
	CheckQuota bool   `json:"check_quota"`
}

func runNetworkProbe(ctx context.Context, in io.Reader, out io.Writer, cfg config, timeout time.Duration) error {
	if err := validateAddress(cfg.UDPTarget); err != nil {
		return fmt.Errorf("UDP probe target: %w", err)
	}
	clientConfig, err := phaseFCNConfig(cfg)
	if err != nil {
		return err
	}
	clientConfig.EnableUDP = true
	client, err := fcnv3.NewClient(clientConfig)
	if err != nil {
		return err
	}
	defer client.Close()
	enc := json.NewEncoder(out)
	scanner := bufio.NewScanner(in)
	scanner.Buffer(make([]byte, 512), 4096)
	var previous string
	var held *fcnv3.UDPAssociation
	defer func() {
		if held != nil {
			held.Close()
		}
	}()
	for iteration := 1; iteration <= 20 && scanner.Scan(); iteration++ {
		started := time.Now()
		var cmd networkCommand
		if err := json.Unmarshal(scanner.Bytes(), &cmd); err != nil || cmd.TCP < 1 || cmd.TCP > 16 || cmd.UDP < 1 || cmd.UDP > 32 {
			return errors.New("invalid network probe command")
		}
		if err := client.UpdateNetwork(cmd.Network); err != nil {
			return err
		}
		changed := previous != "" && previous != cmd.Network
		result := map[string]any{"event": "network-probe", "iteration": iteration, "changed": changed, "tcp_attempts": cmd.TCP, "udp_attempts": cmd.UDP}
		if held != nil {
			if changed {
				receiveCtx, cancel := context.WithTimeout(ctx, time.Second)
				_, readErr := held.ReceiveDatagram(receiveCtx)
				result["old_udp_closed"] = readErr != nil && !errors.Is(readErr, context.DeadlineExceeded)
				cancel()
			}
			held.Close()
			held = nil
		}
		previous = cmd.Network
		tcpOK := 0
		var tcpErrors []string
		handle := benchClient{dial: client.Dial}
		opts := options{Phase: "warm", Protocol: "fcnv3", Bytes: 8192, Workers: 1, Timeout: timeout}
		for i := 1; i <= cmd.TCP; i++ {
			row := measureSample(ctx, opts, cfg.Target, i, &handle, nil, nil)
			if row.Success {
				if tcpOK == 0 {
					result["first_tcp_ms"] = milliseconds(time.Since(started))
				}
				tcpOK++
			} else {
				tcpErrors = append(tcpErrors, row.ErrorStage+":"+row.ErrorCategory)
			}
		}
		result["tcp_success"] = tcpOK
		result["tcp_failures"] = tcpErrors
		udpCtx, stop := context.WithTimeout(ctx, timeout)
		held, err = client.DialUDP(udpCtx, cfg.UDPTarget)
		stop()
		udpOK := 0
		var datagrams []map[string]any
		if err == nil {
			result["udp_oversize_rejected"] = errors.Is(held.SendDatagram(make([]byte, fcnv3.MaxUDPPayload+1)), fcnv3.ErrUDPPayloadTooLarge)
			sizes := []int{64, 256, 512, 900, 1000, 1100, fcnv3.MaxUDPPayload}
			for i := 0; i < cmd.UDP; i++ {
				size := sizes[i%len(sizes)]
				payload := bytes.Repeat([]byte{byte(iteration), byte(i), 0x5e}, (size+2)/3)[:size]
				sample := map[string]any{"sequence": i, "bytes": size, "sent": false, "success": false}
				sampleStart := time.Now()
				sendErr := held.SendDatagram(payload)
				if sendErr != nil {
					sample["error"] = errorCategory(sendErr)
				} else {
					sample["sent"] = true
					receiveCtx, stop := context.WithTimeout(ctx, 1500*time.Millisecond)
					for {
						actual, readErr := held.ReceiveDatagram(receiveCtx)
						if readErr != nil {
							sample["error"] = errorCategory(readErr)
							break
						}
						if bytes.Equal(actual, payload) {
							sample["success"] = true
							if udpOK == 0 {
								result["first_udp_ms"] = milliseconds(time.Since(started))
							}
							udpOK++
							break
						}
						// A delayed reply from a previous sample is not this sample's echo.
					}
					stop()
				}
				sample["elapsed_ms"] = milliseconds(time.Since(sampleStart))
				datagrams = append(datagrams, sample)
			}
		} else {
			result["udp_error"] = errorCategory(err)
		}
		result["udp_success"] = udpOK
		result["udp_rows"] = datagrams
		if cmd.CheckQuota && held != nil {
			result["udp_quota"] = checkUDPQuota(ctx, client, cfg.UDPTarget, held)
		}
		result["elapsed_ms"] = milliseconds(time.Since(started))
		if err := enc.Encode(result); err != nil {
			return err
		}
	}
	return scanner.Err()
}

func checkUDPQuota(ctx context.Context, client *fcnv3.Client, target string, first *fcnv3.UDPAssociation) map[string]any {
	leases := []*fcnv3.UDPAssociation{first}
	defer func() {
		for _, lease := range leases[1:] {
			lease.Close()
		}
	}()
	for len(leases) < 8 {
		dialCtx, cancel := context.WithTimeout(ctx, 3*time.Second)
		lease, err := client.DialUDP(dialCtx, target)
		cancel()
		if err != nil {
			break
		}
		leases = append(leases, lease)
	}
	result := map[string]any{"accepted": len(leases)}
	dialCtx, cancel := context.WithTimeout(ctx, 3*time.Second)
	extra, err := client.DialUDP(dialCtx, target)
	cancel()
	if extra != nil {
		extra.Close()
	}
	result["ninth_rejected"] = len(leases) == 8 && errors.Is(err, fcnv3.ErrRejected)
	if len(leases) == 8 {
		leases[7].Close()
		for attempt := 0; attempt < 3; attempt++ {
			select {
			case <-ctx.Done():
				return result
			case <-time.After(150 * time.Millisecond):
			}
			dialCtx, cancel := context.WithTimeout(ctx, 3*time.Second)
			reused, err := client.DialUDP(dialCtx, target)
			cancel()
			if err == nil {
				reused.Close()
				result["capacity_reused"] = true
				break
			}
		}
	}
	return result
}
