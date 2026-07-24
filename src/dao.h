// 学生成绩管理系统 — 数据访问层
// 基于 libpq 直连 PostgreSQL

#ifndef SRC_DAO_H_
#define SRC_DAO_H_

#include <string>
#include <vector>

#include "models.h"

// 建立数据库连接，成功返回 true
bool ConnectDb(const DbConfig& config);

// 关闭数据库连接
void DisconnectDb();

// 获取所有不重复班级，按班级名排序
std::vector<std::string> QueryClasses();

// 透视查询学生成绩
// classFilter 为空时查询全部学生，否则按班级筛选
// 每行包含学生信息 + 各科成绩（语文/数学/英语/科学）
std::vector<PivotRow> QueryPivot(const std::string& classFilter);

#endif  // SRC_DAO_H_
