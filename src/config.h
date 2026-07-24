// 学生成绩管理系统 — 配置管理
// 从环境变量读取数据库连接信息

#ifndef SRC_CONFIG_H_
#define SRC_CONFIG_H_

#include "models.h"

// 从环境变量读取数据库连接配置
// 未设置的环境变量使用默认值:
//   DB_HOST=db, DB_PORT=5432, DB_NAME=student_grades,
//   DB_USER=student_app, DB_PASSWORD=student_pass
DbConfig LoadDbConfig();

#endif  // SRC_CONFIG_H_
