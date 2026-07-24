# Task 2 Report: 数据模型定义 (models.h)

## File Created
- `/home/fh/exame_test2/src/models.h`

## Structures Defined
| Struct | Fields | Purpose |
|--------|--------|---------|
| `Student` | `id`, `name`, `className` | 学生基本信息 |
| `Score` | `id`, `studentId`, `subject`, `score` | 单科成绩记录 |
| `PivotRow` | `studentId`, `studentName`, `className`, `scores` | 成绩透视行（科目→分数 map） |
| `DbConfig` | `host`, `port`, `dbName`, `user`, `password` | 数据库连接配置 |

## Compilation Verification
Command:
```
g++ -std=c++11 -Wall -Wextra -Isrc -fsyntax-only src/models.h
```

Output: (none) — compilation passed with zero errors and zero warnings.

## Concerns
None. The header is self-contained, uses proper include guards, and includes only `<map>` and `<string>` as required dependencies. All four structs match the specification exactly.
