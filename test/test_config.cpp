// 学生成绩管理系统 — Config 模块测试

#include <gtest/gtest.h>

#include "config.h"

#include <cstdlib>

// 辅助函数：临时设置环境变量
class EnvGuard {
 public:
  EnvGuard(const char* name, const char* value)
      : name_(name) {
    oldValue_ = std::getenv(name);
    Set(name, value);
  }
  ~EnvGuard() {
    Set(name_, oldValue_);
  }
 private:
  void Set(const char* name, const char* value) {
    if (value != nullptr) {
      setenv(name, value, 1);
    } else {
      unsetenv(name);
    }
  }
  const char* name_;
  const char* oldValue_;
};

// TC-C01: 环境变量读取
TEST(ConfigTest, ReadsEnvironmentVariables) {
  EnvGuard g1("DB_HOST", "testhost");
  EnvGuard g2("DB_PORT", "5433");
  EnvGuard g3("DB_NAME", "testdb");
  EnvGuard g4("DB_USER", "testuser");
  EnvGuard g5("DB_PASSWORD", "testpass");

  DbConfig cfg = LoadDbConfig();

  EXPECT_EQ(cfg.host, "testhost");
  EXPECT_EQ(cfg.port, 5433);
  EXPECT_EQ(cfg.dbName, "testdb");
  EXPECT_EQ(cfg.user, "testuser");
  EXPECT_EQ(cfg.password, "testpass");
}

// TC-C02: 默认值回退
TEST(ConfigTest, FallsBackToDefaultsWhenEnvUnset) {
  unsetenv("DB_HOST");
  unsetenv("DB_PORT");
  unsetenv("DB_NAME");
  unsetenv("DB_USER");
  unsetenv("DB_PASSWORD");

  DbConfig cfg = LoadDbConfig();

  EXPECT_EQ(cfg.host, "db");
  EXPECT_EQ(cfg.port, 5432);
  EXPECT_EQ(cfg.dbName, "student_grades");
  EXPECT_EQ(cfg.user, "student_app");
  EXPECT_EQ(cfg.password, "student_pass");
}
