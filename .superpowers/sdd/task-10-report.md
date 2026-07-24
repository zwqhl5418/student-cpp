# Task 10: 单元测试 — 完成报告

## 创建的文件

| 文件 | 测试数量 | 依赖 |
|------|----------|------|
| `test/test_service.cpp` | 4 | config.h, dao.h, service.h, gtest, PostgreSQL |
| `test/test_dao.cpp` | 4 | config.h, dao.h, models.h, gtest, PostgreSQL |
| `test/test_template.cpp` | 3 | models.h, template.h, gtest (纯逻辑，无数据库) |
| `test/test_config.cpp` | 2 (Task 3 已有) | config.h, gtest |

## 测试清单

### test_service.cpp (4 tests)
- **TC-S01** (GetClassesReturnsAllDistinctClasses): 验证 GetClasses() 返回至少一个班级且排序正确
- **TC-S02** (GetStudentScoresReturnsAllStudentsWhenNoFilter): 无筛选查询返回全部学生，验证 class ASC, name ASC 排序
- **TC-S03** (GetStudentScoresFiltersByClass): 按班级筛选，验证所有行 className 一致
- **TC-S04** (GetStudentScoresReturnsEmptyForNonexistentClass): 不存在班级返回空结果

### test_dao.cpp (4 tests)
- **TC-D01** (ConnectsSuccessfully): 验证 SetUp 中的连接建立成功
- **TC-D02** (QueryClassesReturnsResults): QueryClasses 返回至少一个非空班级名
- **TC-D03** (PreventsSqlInjection): 注入字符串返回空，表结构未破坏
- **TC-D04** (QueryPivotIncludesScores): 透视结果包含分数（有数据时）

### test_template.cpp (3 tests)
- **TC-T01** (RendersNormalData): 正常数据渲染 title/下拉框/table/学生名/分数
- **TC-T02** (RendersEmptyStateWhenNoData): 空数据显示"暂无成绩数据"，无 `<table>`
- **TC-T03** (PreservesSelectedClass): 筛选状态恢复的 selected 属性正确

## 总计: 11 个测试用例

## 编译验证

需要 gtest 和 libpq-dev 头文件，本地可能因缺少依赖失败。Docker 环境中通过：

```bash
for f in test/test_*.cpp; do
  echo "检查 $f ..."
  g++ -std=c++11 -Wall -Wextra -Isrc -I/usr/include -fsyntax-only "$f"
done
```
