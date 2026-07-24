# Task 12: Integration Test Script

## Summary

Created `/home/fh/exame_test2/test.sh` — a curl-driven end-to-end integration test script for the student grade management system.

## Test Cases

| ID | Description | Type |
|----|-------------|------|
| TC-I01 | Homepage returns HTTP 200 | Status |
| TC-I02 | Page title contains "教育成绩数据分析平台" | Content |
| TC-I03 | Seed data (张三, 李四) present | Data |
| TC-I04 | Class filter correctly includes/excludes students | Filter |
| TC-I05 | Empty result shows "暂无成绩数据" | Edge case |
| TC-I06 | HTML contains `<table>` and "全部班级" option | Structure |

## Usage

```bash
./test.sh       # Test Scheme A (port 8080)
./test.sh A     # Test Scheme A (port 8080)
./test.sh D     # Test Scheme D (port 8081)
```

## Status

- [x] `test.sh` created and executable (chmod +x)
- [x] Supports both Scheme A (8080) and Scheme D (8081)
- [x] Enforces `set -euo pipefail` for strict error handling
- [x] Exits with code 1 on any test failure
