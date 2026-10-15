# frontend

Static React app built with Vite and served from S3 through CloudFront. The API base URL
is injected at build time through `VITE_API_URL`; the deploy workflow reads it from the
`/<project>/<env>/api/url` SSM parameter.
