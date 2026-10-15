# api

Small Go service behind the ALB. Endpoints: `/healthz`, `/readyz`, `/api/v1/info`,
`/api/v1/notes` (GET, POST). `api migrate` applies the embedded SQL migrations and runs
as an Argo CD PreSync hook before each rollout.

Configuration is environment-only: `PORT`, `ENVIRONMENT`, `LOG_LEVEL`,
`CORS_ALLOWED_ORIGIN`, `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER`, `DB_PASSWORD`,
`DB_SSLMODE`.
