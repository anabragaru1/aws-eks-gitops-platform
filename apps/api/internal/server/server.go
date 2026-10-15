package server

import (
	"context"
	"encoding/json"
	"errors"
	"log/slog"
	"net/http"
	"strings"
	"time"

	"github.com/anabragaru1/aws-eks-gitops-platform/apps/api/internal/store"
)

type Info struct {
	Service     string `json:"service"`
	Version     string `json:"version"`
	Environment string `json:"environment"`
	PodName     string `json:"-"`
}

// Status is the payload of GET /; pod_name rotates across replicas behind the ALB.
type Status struct {
	PodName   string `json:"pod_name"`
	DBStatus  string `json:"db_status"`
	Timestamp string `json:"timestamp"`
}

type Server struct {
	store         store.NoteStore
	log           *slog.Logger
	info          Info
	allowedOrigin string
}

func New(s store.NoteStore, log *slog.Logger, info Info, allowedOrigin string) http.Handler {
	if info.Service == "" {
		info.Service = "api"
	}
	srv := &Server{store: s, log: log, info: info, allowedOrigin: allowedOrigin}

	mux := http.NewServeMux()
	mux.HandleFunc("GET /{$}", srv.status)
	mux.HandleFunc("GET /healthz", srv.healthz)
	mux.HandleFunc("GET /readyz", srv.readyz)
	mux.HandleFunc("GET /api/v1/info", srv.getInfo)
	mux.HandleFunc("GET /api/v1/notes", srv.listNotes)
	mux.HandleFunc("POST /api/v1/notes", srv.createNote)
	mux.HandleFunc("OPTIONS /api/v1/", srv.preflight)

	return srv.cors(srv.logging(mux))
}

func (s *Server) status(w http.ResponseWriter, r *http.Request) {
	ctx, cancel := context.WithTimeout(r.Context(), 2*time.Second)
	defer cancel()

	out := Status{
		PodName:   s.info.PodName,
		DBStatus:  "connected",
		Timestamp: time.Now().UTC().Format(time.RFC3339),
	}
	code := http.StatusOK
	if err := s.store.Check(ctx); err != nil {
		s.log.Error("database check failed", "error", err)
		out.DBStatus = "disconnected"
		code = http.StatusServiceUnavailable
	}
	writeJSON(w, code, out)
}

func (s *Server) healthz(w http.ResponseWriter, _ *http.Request) {
	writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
}

func (s *Server) readyz(w http.ResponseWriter, r *http.Request) {
	ctx, cancel := context.WithTimeout(r.Context(), 2*time.Second)
	defer cancel()
	if err := s.store.Ping(ctx); err != nil {
		writeJSON(w, http.StatusServiceUnavailable, map[string]string{"status": "database unavailable"})
		return
	}
	writeJSON(w, http.StatusOK, map[string]string{"status": "ready"})
}

func (s *Server) getInfo(w http.ResponseWriter, _ *http.Request) {
	writeJSON(w, http.StatusOK, s.info)
}

func (s *Server) listNotes(w http.ResponseWriter, r *http.Request) {
	notes, err := s.store.ListNotes(r.Context())
	if err != nil {
		s.fail(w, err)
		return
	}
	writeJSON(w, http.StatusOK, notes)
}

func (s *Server) createNote(w http.ResponseWriter, r *http.Request) {
	var in struct {
		Text string `json:"text"`
	}
	if err := json.NewDecoder(http.MaxBytesReader(w, r.Body, 4096)).Decode(&in); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid json"})
		return
	}
	in.Text = strings.TrimSpace(in.Text)
	if in.Text == "" || len(in.Text) > 500 {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "text must be 1-500 characters"})
		return
	}

	note, err := s.store.CreateNote(r.Context(), in.Text)
	if errors.Is(err, store.ErrInvalid) {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "text rejected"})
		return
	}
	if err != nil {
		s.fail(w, err)
		return
	}
	writeJSON(w, http.StatusCreated, note)
}

func (s *Server) preflight(w http.ResponseWriter, _ *http.Request) {
	w.WriteHeader(http.StatusNoContent)
}

func (s *Server) fail(w http.ResponseWriter, err error) {
	s.log.Error("request failed", "error", err)
	writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "internal error"})
}

func (s *Server) cors(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if strings.HasPrefix(r.URL.Path, "/api/") {
			w.Header().Set("Access-Control-Allow-Origin", s.allowedOrigin)
			w.Header().Set("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
			w.Header().Set("Access-Control-Allow-Headers", "Content-Type")
			w.Header().Set("Vary", "Origin")
		}
		next.ServeHTTP(w, r)
	})
}

func (s *Server) logging(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path == "/healthz" || r.URL.Path == "/readyz" {
			next.ServeHTTP(w, r)
			return
		}
		start := time.Now()
		rec := &statusRecorder{ResponseWriter: w, status: http.StatusOK}
		next.ServeHTTP(rec, r)
		s.log.Info("request",
			"method", r.Method,
			"path", r.URL.Path,
			"status", rec.status,
			"duration_ms", time.Since(start).Milliseconds(),
		)
	})
}

type statusRecorder struct {
	http.ResponseWriter
	status int
}

func (r *statusRecorder) WriteHeader(code int) {
	r.status = code
	r.ResponseWriter.WriteHeader(code)
}

func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(v)
}
