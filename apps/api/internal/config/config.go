package config

import (
	"fmt"
	"log/slog"
	"net/url"
	"os"
	"strings"
)

type Config struct {
	Port              string
	Environment       string
	PodName           string
	LogLevel          slog.Level
	CORSAllowedOrigin string

	DBHost     string
	DBPort     string
	DBName     string
	DBUser     string
	DBPassword string
	DBSSLMode  string
}

func Load() (Config, error) {
	cfg := Config{
		Port:              getenv("PORT", "8080"),
		Environment:       getenv("ENVIRONMENT", "local"),
		PodName:           getenv("POD_NAME", hostname()),
		CORSAllowedOrigin: getenv("CORS_ALLOWED_ORIGIN", "*"),
		DBHost:            getenv("DB_HOST", "localhost"),
		DBPort:            getenv("DB_PORT", "5432"),
		DBName:            getenv("DB_NAME", "app"),
		DBUser:            os.Getenv("DB_USER"),
		DBPassword:        os.Getenv("DB_PASSWORD"),
		DBSSLMode:         getenv("DB_SSLMODE", "require"),
	}

	if cfg.DBUser == "" || cfg.DBPassword == "" {
		return cfg, fmt.Errorf("DB_USER and DB_PASSWORD are required")
	}

	switch strings.ToLower(getenv("LOG_LEVEL", "info")) {
	case "debug":
		cfg.LogLevel = slog.LevelDebug
	case "warn":
		cfg.LogLevel = slog.LevelWarn
	case "error":
		cfg.LogLevel = slog.LevelError
	default:
		cfg.LogLevel = slog.LevelInfo
	}
	return cfg, nil
}

func (c Config) DatabaseURL() string {
	u := url.URL{
		Scheme:   "postgres",
		User:     url.UserPassword(c.DBUser, c.DBPassword),
		Host:     c.DBHost + ":" + c.DBPort,
		Path:     "/" + c.DBName,
		RawQuery: "sslmode=" + c.DBSSLMode,
	}
	return u.String()
}

func hostname() string {
	h, err := os.Hostname()
	if err != nil {
		return "unknown"
	}
	return h
}

func getenv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}
