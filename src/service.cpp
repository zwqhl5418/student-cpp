// 学生成绩管理系统 — 业务逻辑层实现

#include "service.h"

#include "dao.h"

std::vector<std::string> GetClasses() {
  return QueryClasses();
}

std::vector<PivotRow> GetStudentScores(const std::string& classFilter) {
  return QueryPivot(classFilter);
}
