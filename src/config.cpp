// 学生成绩管理系统 — 配置管理实现

#include "config.h"

#include <cstdlib>
#include <string>

namespace {

// 从环境变量读取字符串，未设置时返回默认值
std::string GetEnv(const char* name, const std::string& defaultVal) {
  const char* val = std::getenv(name);
  if (val != nullptr && val[0] != '\0') {
    return std::string(val);
  }
  return defaultVal;
}

// 从环境变量读取整数，未设置时返回默认值
int GetEnvInt(const char* name, int defaultVal) {
  const char* val = std::getenv(name);
  if (val != nullptr && val[0] != '\0') {
    return std::atoi(val);
  }
  return defaultVal;
}

}  // namespace

DbConfig LoadDbConfig() {
  DbConfig config;
  config.host     = GetEnv("DB_HOST", "db");
  config.port     = GetEnvInt("DB_PORT", 5432);
  config.dbName   = GetEnv("DB_NAME", "student_grades");
  config.user     = GetEnv("DB_USER", "student_app");
  config.password = GetEnv("DB_PASSWORD", "student_pass");
  return config;
}
