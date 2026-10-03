// tailnet-on-demand is a private HTTP hop between Caddy and dormant services.
// Only the root-owned configuration supplies commands and backend addresses.
package main

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"net"
	"net/http"
	"net/http/httputil"
	"net/url"
	"os"
	"os/exec"
	"path/filepath"
	"sync"
	"syscall"
	"time"
)

type targetConfig struct {
	Port           int      `json:"port"`
	Start          []string `json:"start"`
	Stop           []string `json:"stop"`
	IdleTimeout    int      `json:"idleTimeout"`
	StartupTimeout int      `json:"startupTimeout"`
	StopTimeout    int      `json:"stopTimeout"`
}

type configuration struct {
	Socket        string                  `json:"socket"`
	StateDir      string                  `json:"stateDir"`
	CheckInterval int                     `json:"checkInterval"`
	Targets       map[string]targetConfig `json:"targets"`
}

type service struct {
	mu       sync.Mutex // Serializes startup, admission, and idle shutdown.
	cfg      targetConfig
	address  string
	marker   string
	managed  bool
	ready    bool
	active   int
	lastUsed time.Time
	proxy    *httputil.ReverseProxy
	run      func(context.Context, []string) error
}

func runCommand(ctx context.Context, args []string) error {
	cmd := exec.CommandContext(ctx, args[0], args[1:]...)
	cmd.Stdout, cmd.Stderr = os.Stdout, os.Stderr
	// Kill the entire script on timeout, including a blocked systemctl child.
	cmd.SysProcAttr = &syscall.SysProcAttr{Setpgid: true}
	cmd.Cancel = func() error { return syscall.Kill(-cmd.Process.Pid, syscall.SIGKILL) }
	cmd.WaitDelay = time.Second
	return cmd.Run()
}

func newService(cfg targetConfig, marker string) (*service, error) {
	_, err := os.Stat(marker)
	if err != nil && !errors.Is(err, os.ErrNotExist) {
		return nil, err
	}
	s := &service{
		cfg: cfg, address: fmt.Sprintf("127.0.0.1:%d", cfg.Port), marker: marker,
		managed: err == nil, lastUsed: time.Now(), run: runCommand,
	}
	s.proxy = &httputil.ReverseProxy{
		Rewrite: func(r *httputil.ProxyRequest) {
			r.SetURL(&url.URL{Scheme: "http", Host: s.address})
			// Preserve the original query; ReverseProxy cleans it before Rewrite.
			r.Out.URL.RawQuery = r.In.URL.RawQuery
			// Caddy already sanitized these at the public-facing hop.
			for _, h := range []string{"X-Forwarded-For", "X-Forwarded-Host", "X-Forwarded-Proto"} {
				r.Out.Header[h] = r.In.Header.Values(h)
			}
		},
		FlushInterval: -1,
	}
	return s, nil
}

func (s *service) listening(ctx context.Context) bool {
	dialer := net.Dialer{Timeout: 200 * time.Millisecond}
	conn, err := dialer.DialContext(ctx, "tcp", s.address)
	if err != nil {
		return false
	}
	conn.Close()
	return true
}

// begin keeps the original request (including its unread body) waiting until
// the backend listens. Concurrent cold requests share a single startup.
func (s *service) begin(ctx context.Context) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	if err := ctx.Err(); err != nil {
		return err
	}
	s.lastUsed = time.Now()
	if !s.ready || !s.listening(ctx) {
		s.ready = false
		// Persist ownership before starting, so partial starts and helper
		// restarts can still be cleaned up. /run clears this on reboot.
		if err := os.WriteFile(s.marker, nil, 0600); err != nil {
			return err
		}
		s.managed = true
		startup, cancel := context.WithTimeout(ctx, time.Duration(s.cfg.StartupTimeout)*time.Second)
		defer cancel()
		if err := s.run(startup, s.cfg.Start); err != nil {
			return fmt.Errorf("start: %w", err)
		}
		for !s.listening(startup) {
			select {
			case <-startup.Done():
				return fmt.Errorf("waiting for %s: %w", s.address, startup.Err())
			case <-time.After(100 * time.Millisecond):
			}
		}
		s.ready = true
	}
	s.active++
	return nil
}

func (s *service) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	if err := s.begin(r.Context()); err != nil {
		log.Printf("%s startup failed: %v", s.address, err)
		w.Header().Set("Retry-After", "5")
		http.Error(w, "Service is not ready", http.StatusServiceUnavailable)
		return
	}
	defer func() {
		s.mu.Lock()
		defer s.mu.Unlock()
		s.active--
		// Count completion too: downloads, SSE and WebSockets get a full
		// idle period after they finish, regardless of their duration.
		s.lastUsed = time.Now()
	}()
	if r.Method == http.MethodOptions {
		w.WriteHeader(http.StatusNoContent)
		return
	}
	s.proxy.ServeHTTP(w, r)
}

func (s *service) stopIdle(now time.Time) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if !s.managed || s.active != 0 || s.cfg.IdleTimeout == 0 || now.Sub(s.lastUsed) < time.Duration(s.cfg.IdleTimeout)*time.Second {
		return
	}
	ctx, cancel := context.WithTimeout(context.Background(), time.Duration(s.cfg.StopTimeout)*time.Second)
	defer cancel()
	// Requests wait for this stop before attempting a fresh start.
	s.ready = false
	if err := s.run(ctx, s.cfg.Stop); err != nil {
		log.Printf("%s idle shutdown failed (will retry): %v", s.address, err)
		return
	}
	if err := os.Remove(s.marker); err != nil && !errors.Is(err, os.ErrNotExist) {
		log.Printf("%s removing state: %v", s.address, err)
	}
	s.managed = false
	log.Printf("%s stopped after inactivity", s.address)
}

func serve(cfg configuration) error {
	if cfg.CheckInterval <= 0 {
		return errors.New("checkInterval must be positive")
	}
	if err := os.MkdirAll(cfg.StateDir, 0700); err != nil {
		return err
	}
	services := make(map[string]*service)
	done := make(chan struct{})
	defer close(done)
	for name, target := range cfg.Targets {
		if name == "" || name == "." || name == ".." || filepath.Base(name) != name || target.Port < 1 || target.Port > 65535 || len(target.Start) == 0 || target.StartupTimeout <= 0 || target.StopTimeout <= 0 || target.IdleTimeout < 0 || (target.IdleTimeout > 0 && len(target.Stop) == 0) {
			return fmt.Errorf("invalid target %q", name)
		}
		s, err := newService(target, filepath.Join(cfg.StateDir, name))
		if err != nil {
			return err
		}
		services[name] = s
		// Separate tickers keep a slow stop from delaying other services.
		go func() {
			ticker := time.NewTicker(time.Duration(cfg.CheckInterval) * time.Second)
			defer ticker.Stop()
			for {
				select {
				case now := <-ticker.C:
					s.stopIdle(now)
				case <-done:
					return
				}
			}
		}()
	}
	if err := os.Remove(cfg.Socket); err != nil && !errors.Is(err, os.ErrNotExist) {
		return err
	}
	listener, err := net.Listen("unix", cfg.Socket)
	if err != nil {
		return err
	}
	defer listener.Close()
	if err := os.Chmod(cfg.Socket, 0660); err != nil {
		return err
	}
	server := &http.Server{
		ReadHeaderTimeout: 10 * time.Second,
		IdleTimeout:       90 * time.Second,
		Handler: http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			// Caddy overwrites Host with a configured alias. Never derive a
			// command, path or destination port from untrusted request data.
			s, ok := services[r.Host]
			if !ok {
				http.NotFound(w, r)
				return
			}
			s.ServeHTTP(w, r)
		}),
	}
	return server.Serve(listener)
}

func main() {
	if len(os.Args) != 2 {
		log.Fatal("usage: tailnet-on-demand CONFIG.json")
	}
	data, err := os.ReadFile(os.Args[1])
	if err != nil {
		log.Fatal(err)
	}
	var cfg configuration
	if err := json.Unmarshal(data, &cfg); err != nil {
		log.Fatal(err)
	}
	if err := serve(cfg); err != nil {
		log.Fatal(err)
	}
}
