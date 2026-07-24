// 学生成绩管理系统 — 数据模型定义
// 定义系统中使用的核心数据结构

#ifndef SRC_MODELS_H_
#define SRC_MODELS_H_

#include <map>
#include <string>

// 学生基本信息
struct Student {
  int id;
  std::string name;
  std::string className;
};

// 单科成绩记录
struct Score {
  int id;
  int studentId;
  std::string subject;
  double score;  // 可能为 NULL，DA0 层用 NaN 表示
};

// 成绩透视行（一个学生 + 各科成绩）
struct PivotRow {
  int studentId;
  std::string studentName;
  std::string className;
  std::map<std::string, double> scores;  // 科目 → 分数，不含缺科
};

// 数据库连接配置
struct DbConfig {
  std::string host;
  int port;
  std::string dbName;
  std::string user;
  std::string password;
};

#endif  // SRC_MODELS_H_
