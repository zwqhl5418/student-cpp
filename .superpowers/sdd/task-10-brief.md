### Task 10: 单元测试

**Files:**
- Create: `test/test_service.cpp`
- Create: `test/test_dao.cpp`
- Create: `test/test_template.cpp`
- `test/test_config.cpp` 已在 Task 3 创建

**Interfaces:**
- Consumes: 所有 src/ 模块
- Produces: 4 个测试二进制文件

- [ ] **Step 1: 创建 test/test_service.cpp**

```cpp
// 学生成绩管理系统 — Service 模块测试
// 需要 PostgreSQL 数据库连接（在 Docker 测试容器中运行）

#include <gtest/gtest.h>

#include "config.h"
#include "dao.h"
#include "service.h"

class ServiceTest : public ::testing::Test {
 protected:
  void SetUp() override {
    DbConfig cfg = LoadDbConfig();
    ASSERT_TRUE(ConnectDb(cfg));
  }

  void TearDown() override {
    DisconnectDb();
  }
};

// TC-S01: 获取所有不重复班级
TEST_F(ServiceTest, GetClassesReturnsAllDistinctClasses) {
  std::vector<std::string> classes = GetClasses();
  ASSERT_GE(classes.size(), 1u);
  // 验证排序
  for (size_t i = 1; i < classes.size(); ++i) {
    ASSERT_LE(classes[i - 1], classes[i]);
  }
}

// TC-S02: 无筛选条件 — 全部学生
TEST_F(ServiceTest, GetStudentScoresReturnsAllStudentsWhenNoFilter) {
  std::vector<PivotRow> rows = GetStudentScores("");
  ASSERT_GE(rows.size(), 1u);
  // 验证排序: class ASC, name ASC
  for (size_t i = 1; i < rows.size(); ++i) {
    ASSERT_TRUE(
        rows[i - 1].className < rows[i].className ||
        (rows[i - 1].className == rows[i].className &&
         rows[i - 1].studentName <= rows[i].studentName)
    );
  }
}

// TC-S03: 按班级筛选
TEST_F(ServiceTest, GetStudentScoresFiltersByClass) {
  std::vector<std::string> classes = GetClasses();
  if (classes.empty()) {
    GTEST_SKIP() << "无班级数据";
  }
  std::string targetClass = classes[0];

  std::vector<PivotRow> rows = GetStudentScores(targetClass);
  for (size_t i = 0; i < rows.size(); ++i) {
    EXPECT_EQ(rows[i].className, targetClass);
  }
}

// TC-S04: 筛选不存在的班级
TEST_F(ServiceTest, GetStudentScoresReturnsEmptyForNonexistentClass) {
  std::vector<PivotRow> rows = GetStudentScores("不存在的班级_xyz");
  EXPECT_TRUE(rows.empty());
}
```

- [ ] **Step 2: 创建 test/test_template.cpp**

```cpp
// 学生成绩管理系统 — Template 模块测试
// 纯逻辑测试，不需要数据库

#include <gtest/gtest.h>

#include <string>
#include <vector>

#include "models.h"
#include "template.h"

// TC-T01: 正常数据渲染
TEST(TemplateTest, RendersNormalData) {
  std::vector<std::string> classes;
  classes.push_back("一年一班");
  classes.push_back("一年二班");

  PivotRow row;
  row.studentId = 1;
  row.studentName = "张三";
  row.className = "一年一班";
  row.scores["语文"] = 85.0;
  row.scores["数学"] = 90.0;
  row.scores["英语"] = 78.0;
  row.scores["科学"] = 92.0;

  std::vector<PivotRow> rows;
  rows.push_back(row);

  std::string html = RenderPage(classes, rows, "");

  // 验证关键元素
  EXPECT_NE(html.find("<title>教育成绩数据分析平台</title>"),
            std::string::npos);
  EXPECT_NE(html.find("<option value=\"\">全部班级</option>"),
            std::string::npos);
  EXPECT_NE(html.find("<option value=\"一年一班\""), std::string::npos);
  EXPECT_NE(html.find("<table>"), std::string::npos);
  EXPECT_NE(html.find("张三"), std::string::npos);
  EXPECT_NE(html.find("85"), std::string::npos);
}

// TC-T02: 空数据渲染
TEST(TemplateTest, RendersEmptyStateWhenNoData) {
  std::vector<std::string> classes;
  classes.push_back("一年一班");
  std::vector<PivotRow> rows;

  std::string html = RenderPage(classes, rows, "");

  EXPECT_NE(html.find("暂无成绩数据"), std::string::npos);
  EXPECT_EQ(html.find("<table>"), std::string::npos);
}

// TC-T03: 筛选状态恢复
TEST(TemplateTest, PreservesSelectedClass) {
  std::vector<std::string> classes;
  classes.push_back("一年一班");
  classes.push_back("一年二班");
  std::vector<PivotRow> rows;

  std::string html = RenderPage(classes, rows, "一年一班");

  EXPECT_NE(html.find("<option value=\"一年一班\" selected"),
            std::string::npos);
  EXPECT_EQ(html.find("<option value=\"一年二班\" selected"),
            std::string::npos);
}
```

- [ ] **Step 3: 创建 test/test_dao.cpp**

```cpp
// 学生成绩管理系统 — DAO 模块测试
// 需要 PostgreSQL 数据库连接

#include <gtest/gtest.h>

#include <string>
#include <vector>

#include "config.h"
#include "dao.h"
#include "models.h"

class DaoTest : public ::testing::Test {
 protected:
  void SetUp() override {
    DbConfig cfg = LoadDbConfig();
    ASSERT_TRUE(ConnectDb(cfg));
  }

  void TearDown() override {
    DisconnectDb();
  }
};

// TC-D01: 数据库连接成功
TEST_F(DaoTest, ConnectsSuccessfully) {
  // 连接已在 SetUp 中验证
  SUCCEED();
}

// TC-D02: QueryClasses 返回结果
TEST_F(DaoTest, QueryClassesReturnsResults) {
  std::vector<std::string> classes = QueryClasses();
  ASSERT_GE(classes.size(), 1u);
  EXPECT_NE(classes[0], "");
}

// TC-D03: 参数化查询防止 SQL 注入
TEST_F(DaoTest, PreventsSqlInjection) {
  std::vector<PivotRow> rows = QueryPivot("'; DROP TABLE students; --");
  EXPECT_TRUE(rows.empty());
  // 验证表结构完好
  std::vector<std::string> classes = QueryClasses();
  ASSERT_GE(classes.size(), 1u);
}

// TC-D04: QueryPivot 包含分数
TEST_F(DaoTest, QueryPivotIncludesScores) {
  std::vector<PivotRow> rows = QueryPivot("");
  if (rows.empty()) {
    GTEST_SKIP() << "无数据";
  }
  // 至少有一个学生有分数
  bool hasScore = false;
  for (size_t i = 0; i < rows.size() && !hasScore; ++i) {
    hasScore = !rows[i].scores.empty();
  }
  EXPECT_TRUE(hasScore);
}
```

- [ ] **Step 4: 本地语法编译验证**

```bash
# 验证所有 .cpp 文件可编译（不链接，不运行）
for f in test/test_*.cpp; do
  echo "检查 $f ..."
  g++ -std=c++11 -Wall -Wextra -Isrc -I/usr/include -fsyntax-only "$f"
done
# 预期: 全部通过（如果本地没有 gtest 头文件，此步在 Docker 中执行）
```

---

