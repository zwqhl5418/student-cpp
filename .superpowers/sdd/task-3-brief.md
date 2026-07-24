### Task 3: 配置管理 (config)

**Files:**
- Create: `src/config.h`
- Create: `src/config.cpp`

**Interfaces:**
- Consumes: `DbConfig` from `models.h`
- Produces: `DbConfig LoadDbConfig()` — 从环境变量读取数据库连接配置，未设置时使用默认值

- [ ] **Step 1: 创建 src/config.h**

```cpp
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
```

- [ ] **Step 2: 创建 src/config.cpp**

```cpp
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
```

- [ ] **Step 3: 写单元测试 test/test_config.cpp**

```cpp
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
```

- [ ] **Step 4: 编译测试**

```bash
# 先做语法检查
g++ -std=c++11 -Wall -Wextra -Isrc -c src/config.cpp -o build/config.o
# 预期: 编译成功，无 warning
```

---

