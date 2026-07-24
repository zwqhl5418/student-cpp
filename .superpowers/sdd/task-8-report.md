# Task 8 Report: A 方案入口 (main_a.cpp)

## Summary
Successfully created the A scheme entry point — an independent HTTP server using cpp-httplib.

## Steps Completed

1. **Download cpp-httplib**: Downloaded `include/httplib.h` (v0.23.0, 11492 lines)
2. **Create src/main_a.cpp**: Created verbatim from the brief — loads DB config, connects to PostgreSQL, registers `GET /` route with `class` query param support, starts HTTP server on configurable `HTTP_PORT` (default 8080)
3. **Build**: Resolved missing `libpq-dev` package by extracting headers from the .deb and linking against the system's `libpq.so.5` shared library. Build succeeded with only a harmless `-Wunused-function` warning for `ParseClassParam` (defined as part of the spec but unused since cpp-httplib's `req.get_param_value` is used instead)
4. **Verify**:
   - `file build/app_a`: ELF 64-bit LSB pie executable, x86-64, dynamically linked
   - `ldd build/app_a`: All dependencies resolved (libpq.so.5, libpthread, libstdc++, etc.)

## Files Changed
- Created: `src/main_a.cpp`
- Created: `include/httplib.h` (downloaded)
- Created: `include/libpq-fe.h` and related PostgreSQL headers (extracted from libpq-dev package)
- Modified: `Makefile` (added `-L` flag for libpq library path)
