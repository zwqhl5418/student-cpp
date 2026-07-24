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
