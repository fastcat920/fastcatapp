package main

import (
	"bytes"
	"crypto/x509"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net"
	"os"
	"path/filepath"
	"strconv"
	"syscall"

	"github.com/fastcat920/fcn"
	"github.com/gofrs/uuid/v5"
)

type endpointConfig struct {
	Endpoint   string `json:"endpoint"`
	ServerName string `json:"server_name"`
	CAFile     string `json:"ca_file,omitempty"`
}

type fcnAccountConfig struct {
	endpointConfig
	UUID string `json:"uuid"`
}

type config struct {
	Target    string           `json:"target"`
	UDPTarget string           `json:"udp_target,omitempty"`
	FCNv1     fcnAccountConfig `json:"fcnv1"`
	FCNv2     fcnAccountConfig `json:"fcnv2"`
	FCNv3     struct {
		endpointConfig
		Account  string `json:"account"`
		Secret   string `json:"secret"`
		EntryDoH *struct {
			URL         string `json:"url"`
			BootstrapIP string `json:"bootstrap_ip"`
		} `json:"entry_doh,omitempty"`
	} `json:"fcnv3"`
	TUIC struct {
		endpointConfig
		UUID     string `json:"uuid"`
		Password string `json:"password"`
	} `json:"tuic"`
	Hysteria2 struct {
		endpointConfig
		Password string `json:"password"`
	} `json:"hysteria2"`
}

func (cfg *config) endpointFor(protocol string) *endpointConfig {
	switch protocol {
	case "fcnv1":
		return &cfg.FCNv1.endpointConfig
	case "fcnv2":
		return &cfg.FCNv2.endpointConfig
	case "fcnv3":
		return &cfg.FCNv3.endpointConfig
	case "tuic":
		return &cfg.TUIC.endpointConfig
	case "hysteria2":
		return &cfg.Hysteria2.endpointConfig
	default:
		return nil
	}
}

func readPrivateConfig(path string) ([]byte, error) {
	fd, err := syscall.Open(path, syscall.O_RDONLY|syscall.O_NOFOLLOW|syscall.O_NONBLOCK, 0)
	if err != nil {
		return nil, errors.New("private config open failed")
	}
	f := os.NewFile(uintptr(fd), path)
	defer f.Close()
	st, err := f.Stat()
	if err != nil || !st.Mode().IsRegular() || st.Mode().Perm()&0077 != 0 {
		return nil, errors.New("config requires an owner-only regular file")
	}
	if raw, ok := st.Sys().(*syscall.Stat_t); !ok || raw.Uid != uint32(os.Geteuid()) {
		return nil, errors.New("config owner mismatch")
	}
	b, err := io.ReadAll(io.LimitReader(f, 65537))
	if err != nil || len(b) > 65536 {
		return nil, errors.New("config read or size invalid")
	}
	return b, nil
}

func validateAddress(address string) error {
	host, port, err := net.SplitHostPort(address)
	if err != nil || net.ParseIP(host) == nil {
		return errors.New("address must contain a literal IP and port")
	}
	p, err := strconv.ParseUint(port, 10, 16)
	if err != nil || p == 0 {
		return errors.New("invalid port")
	}
	return nil
}

func loadConfig(path, protocol string) (config, error) {
	var cfg config
	b, err := readPrivateConfig(path)
	if err != nil {
		return cfg, err
	}
	d := json.NewDecoder(bytes.NewReader(b))
	d.DisallowUnknownFields()
	if err = d.Decode(&cfg); err != nil {
		return cfg, errors.New("invalid config JSON")
	}
	var extra any
	if d.Decode(&extra) != io.EOF {
		return cfg, errors.New("trailing config data")
	}
	if err = validateAddress(cfg.Target); err != nil {
		return cfg, fmt.Errorf("target: %w", err)
	}
	e := cfg.endpointFor(protocol)
	if e == nil {
		return cfg, errors.New("unsupported benchmark protocol")
	}
	if err = validateAddress(e.Endpoint); err != nil {
		return cfg, fmt.Errorf("endpoint: %w", err)
	}
	if e.ServerName == "" {
		return cfg, errors.New("server_name is required for certificate verification")
	}
	if e.CAFile != "" && !filepath.IsAbs(e.CAFile) {
		e.CAFile = filepath.Join(filepath.Dir(path), e.CAFile)
	}
	switch protocol {
	case "fcnv1", "fcnv2":
		account := cfg.FCNv1.UUID
		if protocol == "fcnv2" {
			account = cfg.FCNv2.UUID
		}
		if _, _, err := fcn.AccountCredentials(account); err != nil {
			return cfg, fmt.Errorf("%s requires a valid UUID", protocol)
		}
	case "fcnv3":
		if cfg.FCNv3.Account == "" || cfg.FCNv3.Secret == "" {
			return cfg, errors.New("FCNv3 account and secret are required")
		}
	case "tuic":
		u, uuidErr := uuid.FromString(cfg.TUIC.UUID)
		if uuidErr != nil || u == uuid.Nil || cfg.TUIC.Password == "" {
			return cfg, errors.New("TUIC UUID and password are required")
		}
	case "hysteria2":
		if cfg.Hysteria2.Password == "" {
			return cfg, errors.New("Hysteria2 password is required")
		}
	}
	return cfg, nil
}

func readRoots(path string) (*x509.CertPool, []byte, error) {
	if path == "" {
		return nil, nil, nil
	}
	pem, err := os.ReadFile(path)
	if err != nil {
		return nil, nil, errors.New("CA file read failed")
	}
	roots, err := x509.SystemCertPool()
	if err != nil {
		roots = x509.NewCertPool()
	}
	if !roots.AppendCertsFromPEM(pem) {
		return nil, nil, errors.New("CA file has no valid PEM certificate")
	}
	return roots, pem, nil
}
