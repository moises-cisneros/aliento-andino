# Feature: HU-16 Despliegue de Producción, Hardening de Seguridad y Verificación E2E

Parent Issue: #52 | Sprint 3 | Delivery: one branch + PR per sub-issue (SUB-16-A #53, SUB-16-B #54)
Test runners: `bash infra/nginx/tests/run.sh` (Docker), Python (`pytest tests/ -v`, `ruff check .`)

## Specs

S1: "Configurar `infra/nginx/nginx.conf` con rate limiting (10 req/s por IP en auth), compresión gzip, terminación SSL y cabeceras de seguridad (`X-Frame-Options: DENY`, `X-Content-Type-Options: nosniff`)."
S2: "Endpoint de healthcheck: `GET /health` responde 200 en $<20\text{ms}$."
S3: "Tráfico excedente: Nginx retorna HTTP `429 Too Many Requests` protegiendo al backend."
S4: "Unitaria: Verificación sintáctica con `nginx -t`. Integración: Test de rate limiting con `wrk` o `ab` (Apache Bench). E2E: Simulación de tráfico de producción HTTPS."
S5: "Ejecutar la suite automatizada E2E que valide el flujo completo: autenticación → listado de lecciones → práctica → guardado → feed social → ranking."
S6: "Cobertura mínima obligatoria: Backend ≥ 80%, Web ≥ 75%, Mobile ≥ 75%." / "Cualquier aserto fallido detiene el pipeline de CI impidiendo el pase a producción."

## Tasks

- [x] T1 (S1-S4) [inline]: Nginx perimetral — HTTPS, redirect 80→443, zona `auth` 10r/s, 429, cabeceras, gzip, healthchecks en compose, test `infra/nginx/tests/run.sh`, job CI, docs (#53 SUB-16-A) — Branch `feat/53-nginx-perimeter-ssl`
- [ ] T2 (S5, S6) [inline]: Suite E2E de humo backend (auth → lecciones → práctica → feed → ranking) (#54 SUB-16-B) — bloqueada por #43 (SUB-12-A, abierta) y por el merge de T1

## Log

L1: "Implementa las subissues de la issue #52 (HU-16), realizalo con ODD, en un propio git worktree."
L2: T1 verification: `bash infra/nginx/tests/run.sh` → all checks pass (nginx -t, 301 redirect, /health 200, auth burst 200s then 429s, X-Frame-Options, nosniff, HSTS, CSP, /health median TTFB ~10ms, gzip; HTTP/2 skipped locally because curl lacks it). `docker compose config -q` valid. `wrk`/`ab` replaced by curl-based parallel burst (no extra tool install, runs in CI).
