# Task 11: Docker Deployment - Report

## Files Created

| File | Description |
|------|-------------|
| `Dockerfile.a` | CentOS 7 build for A-scheme (cpp-httplib, direct) |
| `Dockerfile.d` | CentOS 7 build for D-scheme (FastCGI + nginx + supervisor) |
| `Dockerfile.test` | CentOS 7 build for unit tests with optional coverage |
| `docker-compose.a.yml` | Compose: A-scheme app + PostgreSQL 14 |
| `docker-compose.d.yml` | Compose: D-scheme app + nginx + PostgreSQL 14 |
| `docker-compose.test.yml` | Compose: test runner + PostgreSQL 14 |
| `nginx/default.conf` | nginx config forwarding to FastCGI on port 9000 |
| `supervisord.conf` | Supervisor managing nginx + spawn-fcgi |

## Notes

- All Dockerfiles use `centos:7.9.2009` with Vault mirror fallback for continued compatibility.
- EPEL repos are similarly redirected to Fedora archives.
- `Dockerfile.test` builds Google Test from source (no prebuilt package on CentOS 7).
- Coverage is opt-in via build arg `COVERAGE=1`.
- A-scheme exposes port 8080; D-scheme exposes port 80 (mapped to 8081 in compose).
- test-db uses an anonymous volume (no `pgdata` persistence).

## Usage

```bash
# A-scheme
docker compose -f docker-compose.a.yml up --build

# D-scheme
docker compose -f docker-compose.d.yml up --build

# Tests (no coverage)
docker compose -f docker-compose.test.yml up --build

# Tests (with coverage)
COVERAGE=1 docker compose -f docker-compose.test.yml up --build
```
