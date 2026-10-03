package main

import (
	"bufio"
	"context"
	"errors"
	"fmt"
	"io"
	"net"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
	"sync/atomic"
	"testing"
	"time"
)

func fixture(t *testing.T, handler http.HandlerFunc) (*service, *httptest.Server, *atomic.Int32, *atomic.Int32) {
	t.Helper()
	backend := httptest.NewUnstartedServer(handler)
	t.Cleanup(backend.Close)
	port := backend.Listener.Addr().(*net.TCPAddr).Port
	s, err := newService(targetConfig{
		Port: port, Start: []string{"start"}, Stop: []string{"stop"},
		IdleTimeout: 10, StartupTimeout: 2, StopTimeout: 1,
	}, filepath.Join(t.TempDir(), "backend"))
	if err != nil {
		t.Fatal(err)
	}
	starts, stops := new(atomic.Int32), new(atomic.Int32)
	s.run = func(_ context.Context, args []string) error {
		if args[0] == "start" {
			if starts.Add(1) == 1 {
				backend.Start()
			}
		} else {
			stops.Add(1)
		}
		return nil
	}
	front := httptest.NewServer(s)
	t.Cleanup(front.Close)
	return s, front, starts, stops
}

func request(t *testing.T, front *httptest.Server, method string) int {
	t.Helper()
	r, err := http.NewRequest(method, front.URL+"/a%2Fb?q=1", strings.NewReader("payload"))
	if err != nil {
		t.Fatal(err)
	}
	r.Header.Set("X-Forwarded-Proto", "https")
	r.Header.Set("X-Forwarded-Host", "app.note.example.test")
	r.Header.Set("X-Forwarded-For", "100.64.0.1")
	resp, err := front.Client().Do(r)
	if err != nil {
		t.Fatal(err)
	}
	defer resp.Body.Close()
	io.Copy(io.Discard, resp.Body)
	return resp.StatusCode
}

func TestColdRequestsForwardUnchangedAndShareStartup(t *testing.T) {
	var received atomic.Int32
	s, front, starts, stops := fixture(t, func(w http.ResponseWriter, r *http.Request) {
		body, _ := io.ReadAll(r.Body)
		if r.Method != "POST" || r.RequestURI != "/a%2Fb?q=1" || string(body) != "payload" || !strings.HasPrefix(r.Host, "127.0.0.1:") || r.Header.Get("X-Forwarded-Proto") != "https" || r.Header.Get("X-Forwarded-Host") != "app.note.example.test" || r.Header.Get("X-Forwarded-For") != "100.64.0.1" {
			t.Errorf("changed request: %s %s host=%s body=%s headers=%v", r.Method, r.RequestURI, r.Host, body, r.Header)
		}
		received.Add(1)
		w.WriteHeader(201)
	})
	s.stopIdle(time.Now().Add(time.Hour))
	if starts.Load() != 0 || stops.Load() != 0 {
		t.Fatal("untouched backend was managed")
	}
	var wg sync.WaitGroup
	for range 12 {
		wg.Add(1)
		go func() {
			defer wg.Done()
			if status := request(t, front, "POST"); status != 201 {
				t.Errorf("status = %d", status)
			}
		}()
	}
	wg.Wait()
	if starts.Load() != 1 || received.Load() != 12 {
		t.Fatalf("starts=%d requests=%d", starts.Load(), received.Load())
	}
	s.stopIdle(time.Now())
	if stops.Load() != 0 {
		t.Fatal("stopped before idle timeout")
	}
	s.stopIdle(time.Now().Add(time.Minute))
	if stops.Load() != 1 {
		t.Fatal("did not stop idle backend")
	}
	if status := request(t, front, "POST"); status != 201 || starts.Load() != 2 {
		t.Fatal("did not start again after idle stop")
	}
}

func TestProxyPreservesRawQuery(t *testing.T) {
	_, front, _, _ := fixture(t, func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprint(w, r.RequestURI)
	})
	for _, tc := range []struct {
		name string
		uri  string
	}{
		{"semicolon", "/find?filter=a;b&ok=1"},
		{"encoding_and_duplicates", "/find?z=%2f%2F%20+%25&filter=a;b&tag=first&tag=second&a=%3b&empty="},
		{"ordinary", "/find?q=1&tag=first&tag=second"},
	} {
		t.Run(tc.name, func(t *testing.T) {
			resp, err := front.Client().Get(front.URL + tc.uri)
			if err != nil {
				t.Fatal(err)
			}
			defer resp.Body.Close()
			body, err := io.ReadAll(resp.Body)
			if err != nil {
				t.Fatal(err)
			}
			if resp.StatusCode != http.StatusOK || string(body) != tc.uri {
				t.Fatalf("status=%d, backend URI=%q; want %q", resp.StatusCode, body, tc.uri)
			}
		})
	}
}

func TestActiveStreamPreventsShutdown(t *testing.T) {
	release := make(chan struct{})
	s, front, _, stops := fixture(t, func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "text/event-stream")
		fmt.Fprint(w, "data: hello\n\n")
		w.(http.Flusher).Flush()
		<-release
	})
	defer close(release)
	resp, err := front.Client().Get(front.URL)
	if err != nil {
		t.Fatal(err)
	}
	defer resp.Body.Close()
	s.stopIdle(time.Now().Add(time.Hour))
	if stops.Load() != 0 {
		t.Fatal("stopped active stream")
	}
}

func TestWebSocketUpgradeStaysActive(t *testing.T) {
	s, front, _, stops := fixture(t, func(w http.ResponseWriter, r *http.Request) {
		conn, rw, err := w.(http.Hijacker).Hijack()
		if err != nil {
			t.Error(err)
			return
		}
		defer conn.Close()
		fmt.Fprint(rw, "HTTP/1.1 101 Switching Protocols\r\nConnection: Upgrade\r\nUpgrade: websocket\r\n\r\n")
		rw.Flush()
		io.Copy(conn, rw) // Echo bytes through the upgraded tunnel.
	})
	conn, err := net.Dial("tcp", strings.TrimPrefix(front.URL, "http://"))
	if err != nil {
		t.Fatal(err)
	}
	defer conn.Close()
	conn.SetDeadline(time.Now().Add(5 * time.Second))
	fmt.Fprint(conn, "GET / HTTP/1.1\r\nHost: app\r\nConnection: Upgrade\r\nUpgrade: websocket\r\n\r\n")
	reader := bufio.NewReader(conn)
	resp, err := http.ReadResponse(reader, nil)
	if err != nil || resp.StatusCode != 101 {
		t.Fatalf("upgrade: %v %v", resp, err)
	}
	fmt.Fprint(conn, "hello")
	data := make([]byte, 5)
	if _, err := io.ReadFull(reader, data); err != nil || string(data) != "hello" {
		t.Fatalf("tunnel: %q %v", data, err)
	}
	s.stopIdle(time.Now().Add(time.Hour))
	if stops.Load() != 0 {
		t.Fatal("stopped active websocket")
	}
	conn.Close()
	deadline := time.Now().Add(time.Second)
	for {
		s.mu.Lock()
		active := s.active
		s.mu.Unlock()
		if active == 0 {
			break
		}
		if time.Now().After(deadline) {
			t.Fatal("websocket activity was not released")
		}
		time.Sleep(time.Millisecond)
	}
	s.stopIdle(time.Now())
	if stops.Load() != 0 {
		t.Fatal("did not reset idle time at websocket close")
	}
	s.stopIdle(time.Now().Add(time.Minute))
	if stops.Load() != 1 {
		t.Fatal("did not stop after websocket closed")
	}
}

func TestFailuresRetryAndSurviveHelperRestart(t *testing.T) {
	s, front, _, _ := fixture(t, func(w http.ResponseWriter, r *http.Request) {})
	s.run = func(context.Context, []string) error { return errors.New("failed start") }
	if status := request(t, front, "GET"); status != 503 {
		t.Fatalf("status=%d", status)
	}
	recovered, err := newService(s.cfg, s.marker)
	if err != nil {
		t.Fatal(err)
	}
	var stops int
	recovered.run = func(context.Context, []string) error {
		stops++
		if stops == 1 {
			return errors.New("failed stop")
		}
		return nil
	}
	recovered.stopIdle(time.Now().Add(time.Minute))
	recovered.stopIdle(time.Now().Add(time.Minute))
	recovered.stopIdle(time.Now().Add(time.Minute))
	if stops != 2 {
		t.Fatalf("stop retries=%d", stops)
	}
	if _, err := os.Stat(s.marker); !errors.Is(err, os.ErrNotExist) {
		t.Fatal("ownership marker not removed")
	}
}

func TestReadinessWaitAndTimeout(t *testing.T) {
	listener, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	address := listener.Addr().String()
	_, portString, _ := net.SplitHostPort(address)
	port, _ := strconv.Atoi(portString)
	listener.Close()
	s, _ := newService(targetConfig{Port: port, StartupTimeout: 1}, filepath.Join(t.TempDir(), "backend"))
	s.run = func(context.Context, []string) error { return nil }
	start := time.Now()
	if err := s.begin(context.Background()); err == nil {
		t.Fatal("unready backend accepted")
	}
	if elapsed := time.Since(start); elapsed < time.Second || elapsed > 3*time.Second {
		t.Fatalf("readiness timeout=%s", elapsed)
	}
	opened := make(chan net.Listener, 1)
	s.run = func(context.Context, []string) error {
		go func() {
			time.Sleep(100 * time.Millisecond)
			listener, err := net.Listen("tcp", address)
			if err != nil {
				t.Error(err)
			}
			opened <- listener
		}()
		return nil
	}
	if err := s.begin(context.Background()); err != nil {
		t.Fatal(err)
	}
	if listener := <-opened; listener != nil {
		listener.Close()
	}
}

func TestPreflightAndDisabledIdleTimeout(t *testing.T) {
	s, front, starts, stops := fixture(t, func(w http.ResponseWriter, r *http.Request) {
		t.Error("preflight forwarded to backend")
	})
	s.cfg.IdleTimeout = 0
	if status := request(t, front, "OPTIONS"); status != 204 || starts.Load() != 1 {
		t.Fatal("preflight did not trigger startup")
	}
	s.stopIdle(time.Now().Add(24 * time.Hour))
	if stops.Load() != 0 {
		t.Fatal("stopped with idle shutdown disabled")
	}
}

func TestRequestWaitsForIdleStop(t *testing.T) {
	s, front, starts, _ := fixture(t, func(w http.ResponseWriter, r *http.Request) {})
	request(t, front, "GET")
	stopping, release, stopped := make(chan struct{}), make(chan struct{}), make(chan struct{})
	original := s.run
	s.run = func(ctx context.Context, args []string) error {
		if args[0] == "stop" {
			close(stopping)
			<-release
		}
		return original(ctx, args)
	}
	go func() {
		s.stopIdle(time.Now().Add(time.Minute))
		close(stopped)
	}()
	<-stopping
	completed := make(chan struct{})
	go func() {
		request(t, front, "GET")
		close(completed)
	}()
	select {
	case <-completed:
		t.Fatal("request passed an ongoing stop")
	case <-time.After(50 * time.Millisecond):
	}
	close(release)
	<-stopped
	<-completed
	if starts.Load() != 2 {
		t.Fatal("request failed to restart after racing idle shutdown")
	}
}
