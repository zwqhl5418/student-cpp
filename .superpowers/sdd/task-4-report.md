# Task 4 Implementation Report — DAO Layer (libpq PostgreSQL Access)

## Files Created

1. **`/home/fh/exame_test2/src/dao.h`** — Data Access Layer header
   - Declares `ConnectDb`, `DisconnectDb`, `QueryClasses`, `QueryPivot`
   - Consumes `DbConfig` from `models.h` and `PivotRow` from `models.h`
   - Follows Google C++ Style Guide with Chinese comments

2. **`/home/fh/exame_test2/src/dao.cpp`** — Data Access Layer implementation
   - Uses libpq (`libpq-fe.h`) for direct PostgreSQL access
   - `ConnectDb` — builds connection string from `DbConfig` and calls `PQconnectdb`
   - `DisconnectDb` — calls `PQfinish` with null-safety
   - `QueryClasses` — executes `SELECT DISTINCT class FROM students ORDER BY class`
   - `QueryPivot` — parameterized pivot query using `PQexecParams` with `$1` placeholder for class filter; uses `CASE` expressions to pivot subjects (语文/数学/英语/科学)
   - Anonymous namespace for global connection pointer (`PGconn* g_conn`) and helper functions
   - Safety helper `GetString` handles NULL values from `PQgetisnull`

## Compilation Verification

**Command attempted:**

```bash
g++ -std=c++11 -Wall -Wextra -Isrc -c src/dao.cpp -o build/dao.o
```

**Result:** Fails with `fatal error: libpq-fe.h: No such file or directory` because `libpq-dev` is not installed on this host (only runtime `libpq.so.5` is present). This is expected outside the Docker/CI container — the task brief notes that the compilation target environment has `libpq-dev` available at `/usr/include`. The alternate command using `pg_config --includedir` was also attempted but `pg_config` is not installed.

In the target Docker/CI environment with `libpq-dev` installed, the compilation is expected to succeed without errors.

## Concerns

- **libpq-dev dependency:** The header `<libpq-fe.h>` requires the `libpq-dev` package. This must be present in the build environment (Dockerfile or CI). The runtime dependency `libpq.so.5` is already on the system.
- **Single-connection global:** The `g_conn` global pointer implies single-connection usage, which is appropriate for a CGI/FastCGI application but would need refactoring for multi-threaded or connection-pool scenarios.
- **Subject names hardcoded:** The four subject names (语文/数学/英语/科学) are hardcoded as application-level constants, matching the PHP version. Any change to subjects requires a code change.
- **SQL injection:** Subject names are concatenated directly into the SQL string in `QueryPivot`. Since they are compile-time constants from the application source, this is not exploitable, but it is worth noting for maintenance.
