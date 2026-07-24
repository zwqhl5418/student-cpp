# Task 5 Report: 业务逻辑层 (Service)

## Files Created

1. `src/service.h` — 业务逻辑层头文件，声明 `GetClasses()` 和 `GetStudentScores()` 接口
2. `src/service.cpp` — 业务逻辑层实现，直接委托给 DAO 层

## Compilation Verification

```bash
$ g++ -std=c++11 -Wall -Wextra -Isrc -c src/service.cpp -o build/service.o
```

**Result: Compilation succeeded with zero errors and zero warnings.**

## Concerns

None. This is a thin wrapper layer that cleanly delegates to the existing DAO layer (`QueryClasses()` and `QueryPivot()`). No concerns.
