package store

import (
	"context"
	"database/sql"
	"errors"
	"time"

	"github.com/jackc/pgx/v5/pgconn"
	_ "github.com/jackc/pgx/v5/stdlib"
)

var ErrInvalid = errors.New("invalid input")

type Note struct {
	ID        int64     `json:"id"`
	Text      string    `json:"text"`
	CreatedAt time.Time `json:"createdAt"`
}

type NoteStore interface {
	Ping(ctx context.Context) error
	Check(ctx context.Context) error
	ListNotes(ctx context.Context) ([]Note, error)
	CreateNote(ctx context.Context, text string) (Note, error)
}

type Postgres struct {
	db *sql.DB
}

func Open(ctx context.Context, dsn string) (*Postgres, error) {
	db, err := sql.Open("pgx", dsn)
	if err != nil {
		return nil, err
	}
	db.SetMaxOpenConns(10)
	db.SetMaxIdleConns(5)
	db.SetConnMaxLifetime(30 * time.Minute)

	pingCtx, cancel := context.WithTimeout(ctx, 10*time.Second)
	defer cancel()
	if err := db.PingContext(pingCtx); err != nil {
		_ = db.Close()
		return nil, err
	}
	return &Postgres{db: db}, nil
}

func (p *Postgres) DB() *sql.DB { return p.db }

func (p *Postgres) Close() error { return p.db.Close() }

func (p *Postgres) Ping(ctx context.Context) error { return p.db.PingContext(ctx) }

// Check runs a real query so the status reflects a working session, not just a socket.
func (p *Postgres) Check(ctx context.Context) error {
	var one int
	if err := p.db.QueryRowContext(ctx, `SELECT 1`).Scan(&one); err != nil {
		return err
	}
	if one != 1 {
		return errors.New("unexpected SELECT 1 result")
	}
	return nil
}

func (p *Postgres) ListNotes(ctx context.Context) ([]Note, error) {
	rows, err := p.db.QueryContext(ctx, `SELECT id, text, created_at FROM notes ORDER BY id DESC LIMIT 100`)
	if err != nil {
		return nil, err
	}
	defer func() { _ = rows.Close() }()

	notes := []Note{}
	for rows.Next() {
		var n Note
		if err := rows.Scan(&n.ID, &n.Text, &n.CreatedAt); err != nil {
			return nil, err
		}
		notes = append(notes, n)
	}
	return notes, rows.Err()
}

func (p *Postgres) CreateNote(ctx context.Context, text string) (Note, error) {
	var n Note
	err := p.db.QueryRowContext(ctx,
		`INSERT INTO notes (text) VALUES ($1) RETURNING id, text, created_at`, text,
	).Scan(&n.ID, &n.Text, &n.CreatedAt)

	var pgErr *pgconn.PgError
	if errors.As(err, &pgErr) && pgErr.Code == "23514" {
		return Note{}, ErrInvalid
	}
	return n, err
}
