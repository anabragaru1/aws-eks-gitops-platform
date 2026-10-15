package migrate

import (
	"context"
	"database/sql"
	"embed"
	"fmt"
	"sort"
)

//go:embed sql/*.sql
var files embed.FS

// Run applies every migration in sql/ that is not yet recorded, in filename order.
func Run(ctx context.Context, db *sql.DB) (int, error) {
	if _, err := db.ExecContext(ctx, `CREATE TABLE IF NOT EXISTS schema_migrations (
		name TEXT PRIMARY KEY,
		applied_at TIMESTAMPTZ NOT NULL DEFAULT now()
	)`); err != nil {
		return 0, err
	}

	entries, err := files.ReadDir("sql")
	if err != nil {
		return 0, err
	}
	names := make([]string, 0, len(entries))
	for _, e := range entries {
		names = append(names, e.Name())
	}
	sort.Strings(names)

	applied := 0
	for _, name := range names {
		var exists bool
		if err := db.QueryRowContext(ctx, `SELECT EXISTS (SELECT 1 FROM schema_migrations WHERE name = $1)`, name).Scan(&exists); err != nil {
			return applied, err
		}
		if exists {
			continue
		}

		body, err := files.ReadFile("sql/" + name)
		if err != nil {
			return applied, err
		}

		tx, err := db.BeginTx(ctx, nil)
		if err != nil {
			return applied, err
		}
		if _, err := tx.ExecContext(ctx, string(body)); err != nil {
			_ = tx.Rollback()
			return applied, fmt.Errorf("%s: %w", name, err)
		}
		if _, err := tx.ExecContext(ctx, `INSERT INTO schema_migrations (name) VALUES ($1)`, name); err != nil {
			_ = tx.Rollback()
			return applied, err
		}
		if err := tx.Commit(); err != nil {
			return applied, err
		}
		applied++
	}
	return applied, nil
}
