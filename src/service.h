// 学生成绩管理系统 — 业务逻辑层
// 封装数据查询，为 Handler 提供语义化接口

#ifndef SRC_SERVICE_H_
#define SRC_SERVICE_H_

#include <string>
#include <vector>

#include "models.h"

// 获取所有不重复班级列表
std::vector<std::string> GetClasses();

// 获取学生成绩透视数据
// classFilter 为空时查询全部学生
std::vector<PivotRow> GetStudentScores(const std::string& classFilter);

#endif  // SRC_SERVICE_H_
