# Task 9: D 方案入口 (FastCGI via libfcgi++)

## Status: Completed

## Steps

### Step 1: Create src/main_d.cpp
- Created `/home/fh/exame_test2/src/main_d.cpp` with the complete FastCGI entry point
- Uses `#ifdef BUILD_SCHEME_D` guard with a fallback `main()` for non-D builds
- FastCGI accept loop calls `HandleIndex(classFilter)` from handler layer
- ParseClassParam extracts the `class=` query parameter from QUERY_STRING

### Step 2: Build
- Installed FastCGI dev libraries locally (no system root access — extracted from deb packages to project `lib/` and `include/`)
- Updated Makefile to add `-lfcgi -lfcgi++ -Llib -Wl,-rpath,lib` for D scheme
- Build command: `make SCHEME=D -j$(nproc)`
- Result: `build/app_d` compiled and linked successfully

### Step 3: Verify
- `file build/app_d`: ELF 64-bit LSB pie executable, x86-64, not stripped
- `ldd build/app_d`: Depends on `libpq.so.5`, `libfcgi.so.0`, `libstdc++.so.6`, `libgcc_s.so.1`, `libc.so.6`

## Binary
- Path: `/home/fh/exame_test2/build/app_d`
- Entry point handles FastCGI requests via `FCGX_Accept_r` loop
- Each request parses `class` query parameter and renders HTML via `HandleIndex`
