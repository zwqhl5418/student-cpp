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
