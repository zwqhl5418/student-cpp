# Task 3 Report — Config Module

## Files Created

1. `src/config.h` — Header declaring `DbConfig LoadDbConfig()` with env-var-based defaults
2. `src/config.cpp` — Implementation with anonymous-namespace helper functions `GetEnv` and `GetEnvInt`
3. `test/test_config.cpp` — Unit tests: TC-C01 (environment variable reads) and TC-C02 (fallback to defaults)

## Compilation Verification

Command:
```
g++ -std=c++11 -Wall -Wextra -Isrc -c src/config.cpp -o build/config.o
```

Output: **Compiled successfully with zero errors and zero warnings.**

Object file created at `build/config.o` (7208 bytes).

## Concerns

None. Implementation matches the spec exactly. All three files were created with exact content from the task brief. The test file includes `test_config.cpp` which will be linked by the test Makefile alongside the config object file.
