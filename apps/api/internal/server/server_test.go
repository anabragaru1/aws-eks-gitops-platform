package server

import (
	"context"
	"encoding/json"
	"errors"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/anabragaru1/aws-eks-gitops-platform/apps/api/internal/store"
)

type fakeStore struct {
	notes   []store.Note
	pingErr error
}

func (f *fakeStore) Ping(context.Context) error { return f.pingErr }

func (f *fakeStore) Check(context.Context) error { return f.pingErr }

func (f *fakeStore) ListNotes(context.Context) ([]store.Note, error) { return f.notes, nil }

func (f *fakeStore) CreateNote(_ context.Context, text string) (store.Note, error) {
	n := store.Note{ID: int64(len(f.notes) + 1), Text: text}
	f.notes = append(f.notes, n)
	return n, nil
}

func newTestServer(fs *fakeStore) http.Handler {
	log := slog.New(slog.NewTextHandler(&strings.Builder{}, nil))
	return New(fs, log, Info{Version: "test", Environment: "test", PodName: "api-abc12"}, "https://app.example.com")
}

func TestStatusReportsPodAndDatabase(t *testing.T) {
	rec := httptest.NewRecorder()
	newTestServer(&fakeStore{}).ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/", nil))
	if rec.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d", rec.Code)
	}
	var out Status
	if err := json.Unmarshal(rec.Body.Bytes(), &out); err != nil {
		t.Fatalf("invalid json: %v", err)
	}
	if out.PodName != "api-abc12" || out.DBStatus != "connected" {
		t.Fatalf("unexpected payload %+v", out)
	}
	if _, err := time.Parse(time.RFC3339, out.Timestamp); err != nil {
		t.Fatalf("timestamp not RFC3339: %q", out.Timestamp)
	}
}

func TestStatusReportsDatabaseFailure(t *testing.T) {
	rec := httptest.NewRecorder()
	newTestServer(&fakeStore{pingErr: errors.New("down")}).ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/", nil))
	if rec.Code != http.StatusServiceUnavailable || !strings.Contains(rec.Body.String(), `"db_status":"disconnected"`) {
		t.Fatalf("unexpected response %d: %s", rec.Code, rec.Body.String())
	}
}

func TestUnknownPathIs404(t *testing.T) {
	rec := httptest.NewRecorder()
	newTestServer(&fakeStore{}).ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/nope", nil))
	if rec.Code != http.StatusNotFound {
		t.Fatalf("expected 404, got %d", rec.Code)
	}
}

func TestHealthz(t *testing.T) {
	rec := httptest.NewRecorder()
	newTestServer(&fakeStore{}).ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/healthz", nil))
	if rec.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d", rec.Code)
	}
}

func TestReadyzReportsDatabaseFailure(t *testing.T) {
	rec := httptest.NewRecorder()
	newTestServer(&fakeStore{pingErr: errors.New("down")}).ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/readyz", nil))
	if rec.Code != http.StatusServiceUnavailable {
		t.Fatalf("expected 503, got %d", rec.Code)
	}
}

func TestCreateAndListNotes(t *testing.T) {
	fs := &fakeStore{}
	srv := newTestServer(fs)

	rec := httptest.NewRecorder()
	srv.ServeHTTP(rec, httptest.NewRequest(http.MethodPost, "/api/v1/notes", strings.NewReader(`{"text":" hello "}`)))
	if rec.Code != http.StatusCreated {
		t.Fatalf("expected 201, got %d: %s", rec.Code, rec.Body.String())
	}
	if !strings.Contains(rec.Body.String(), `"text":"hello"`) {
		t.Fatalf("expected trimmed text in response, got %s", rec.Body.String())
	}

	rec = httptest.NewRecorder()
	srv.ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/api/v1/notes", nil))
	if rec.Code != http.StatusOK || !strings.Contains(rec.Body.String(), `"id":1`) {
		t.Fatalf("unexpected list response %d: %s", rec.Code, rec.Body.String())
	}
	if got := rec.Header().Get("Access-Control-Allow-Origin"); got != "https://app.example.com" {
		t.Fatalf("unexpected CORS origin %q", got)
	}
}

func TestCreateNoteRejectsEmptyText(t *testing.T) {
	rec := httptest.NewRecorder()
	newTestServer(&fakeStore{}).ServeHTTP(rec, httptest.NewRequest(http.MethodPost, "/api/v1/notes", strings.NewReader(`{"text":"   "}`)))
	if rec.Code != http.StatusBadRequest {
		t.Fatalf("expected 400, got %d", rec.Code)
	}
}
