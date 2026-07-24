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
