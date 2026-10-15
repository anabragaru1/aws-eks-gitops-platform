package main

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/anabragaru1/aws-eks-gitops-platform/apps/api/internal/config"
	"github.com/anabragaru1/aws-eks-gitops-platform/apps/api/internal/migrate"
	"github.com/anabragaru1/aws-eks-gitops-platform/apps/api/internal/server"
	"github.com/anabragaru1/aws-eks-gitops-platform/apps/api/internal/store"
)

// Set at build time with -ldflags.
var version = "dev"

func main() {
	cfg, err := config.Load()
	if err != nil {
		fmt.Fprintln(os.Stderr, "config:", err)
		os.Exit(1)
	}

	log := slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{Level: cfg.LogLevel}))
	slog.SetDefault(log)

	if len(os.Args) > 1 && os.Args[1] == "migrate" {
		if err := runMigrate(cfg, log); err != nil {
			log.Error("migration failed", "error", err)
			os.Exit(1)
		}
		return
	}

	if err := runServer(cfg, log); err != nil {
		log.Error("server stopped with error", "error", err)
		os.Exit(1)
	}
}

func runMigrate(cfg config.Config, log *slog.Logger) error {
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Minute)
	defer cancel()

	db, err := store.Open(ctx, cfg.DatabaseURL())
	if err != nil {
		return err
	}
	defer func() { _ = db.Close() }()

	applied, err := migrate.Run(ctx, db.DB())
	if err != nil {
		return err
	}
	log.Info("migrations complete", "applied", applied)
	return nil
}

func runServer(cfg config.Config, log *slog.Logger) error {
	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()

	db, err := store.Open(ctx, cfg.DatabaseURL())
	if err != nil {
		return err
	}
	defer func() { _ = db.Close() }()

	srv := &http.Server{
		Addr:              ":" + cfg.Port,
		Handler:           server.New(db, log, server.Info{Version: version, Environment: cfg.Environment, PodName: cfg.PodName}, cfg.CORSAllowedOrigin),
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       10 * time.Second,
		WriteTimeout:      15 * time.Second,
		IdleTimeout:       60 * time.Second,
	}

	errCh := make(chan error, 1)
	go func() {
		log.Info("listening", "addr", srv.Addr, "version", version, "environment", cfg.Environment)
		errCh <- srv.ListenAndServe()
	}()

	select {
	case err := <-errCh:
		if !errors.Is(err, http.ErrServerClosed) {
			return err
		}
	case <-ctx.Done():
		log.Info("shutting down")
		shutdownCtx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
		defer cancel()
		return srv.Shutdown(shutdownCtx)
	}
	return nil
}
