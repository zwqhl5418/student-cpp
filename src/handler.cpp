// 学生成绩管理系统 — 请求处理器实现

#include "handler.h"

#include <string>
#include <vector>

#include "models.h"
#include "service.h"
#include "template.h"

std::string HandleIndex(const std::string& classFilter) {
  // 获取班级列表
  std::vector<std::string> classes = GetClasses();

  // 获取成绩透视数据
  std::vector<PivotRow> rows = GetStudentScores(classFilter);

  // 渲染 HTML 页面
  return RenderPage(classes, rows, classFilter);
}
