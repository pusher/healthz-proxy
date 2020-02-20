package main

import (
	"context"
	"flag"
	"log"
	"net/http"
	"net/http/httputil"
	"net/url"
	"os"
	"os/signal"
	"sync/atomic"
	"syscall"
	"time"
)

var (
	listenAddr      string
	proxyURL        string
	healthy         int32
	shutdownTimeout time.Duration
	failPeriod      time.Duration
)

const (
	Healthy   = 1
	Unhealthy = 0
)

func isHealthy() bool {
	return atomic.LoadInt32(&healthy) == Healthy
}

func newServer(origin *url.URL, logger *log.Logger) *http.Server {
	director := func(req *http.Request) {
		req.Header.Add("X-Forwarded-Host", req.Host)
		req.URL.Path = origin.Path
		req.URL.Host = origin.Host
		req.URL.Scheme = origin.Scheme
	}
	proxy := httputil.ReverseProxy{Director: director}
	router := http.NewServeMux()
	router.HandleFunc("/healthz", func(w http.ResponseWriter, r *http.Request) {
		if isHealthy() {
			proxy.ServeHTTP(w, r)
		} else {
			w.WriteHeader(http.StatusServiceUnavailable)
		}
	})

	return &http.Server{
		Addr:         listenAddr,
		Handler:      router,
		ErrorLog:     logger,
		ReadTimeout:  5 * time.Second,
		WriteTimeout: 10 * time.Second,
		IdleTimeout:  15 * time.Second,
	}
}

func gracefulShutdown(server *http.Server, logger *log.Logger, quit <-chan os.Signal, done chan<- bool) {
	<-quit
	logger.Printf("failing health checks for %v\n", failPeriod)
	atomic.StoreInt32(&healthy, Unhealthy)

	time.AfterFunc(failPeriod, func() {
		logger.Printf("terminate timeout exceeded, shutting down server with timeout %v\n", shutdownTimeout)
		ctx, cancel := context.WithTimeout(context.Background(), shutdownTimeout)
		defer cancel()

		server.SetKeepAlivesEnabled(false)
		if err := server.Shutdown(ctx); err != nil {
			logger.Fatalf("could not gracefully shutdown the server: %v\n", err)
		}
		logger.Println("shutdown completed, closing done")
		close(done)
	})
}

func main() {
	flag.StringVar(&listenAddr, "listen-addr", ":8080", "server listen address")
	flag.StringVar(&proxyURL, "proxy-url", "http://:8081/healthz", "URL to proxy to")
	flag.DurationVar(&shutdownTimeout, "shutdown-timeout", 5*time.Second, "time to wait for server to stop gracefully")
	flag.DurationVar(&failPeriod, "fail-period", 30*time.Second, "time to fail health checks for before stopping server")
	flag.Parse()

	logger := log.New(os.Stdout, "http: ", log.LstdFlags)

	healthzURL, err := url.Parse(proxyURL)
	if err != nil {
		logger.Fatalf("could not parse proxy URL %v\n", proxyURL, err)
	}
	atomic.StoreInt32(&healthy, Healthy)

	done := make(chan bool, 1)
	quit := make(chan os.Signal, 1)

	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)

	server := newServer(healthzURL, logger)
	go gracefulShutdown(server, logger, quit, done)

	logger.Printf("server starting on %v, proxying requests to %v\n", listenAddr, healthzURL)
	if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
		logger.Fatalf("could not listen on %s: %v\n", listenAddr, err)
	}

	<-done
	logger.Println("server stopped")
}
