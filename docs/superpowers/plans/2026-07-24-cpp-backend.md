# 学生成绩管理系统 C++ 后端 — 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 使用 C++11 重写 PHP 后端，保持功能完全等价，同时提供 cpp-httplib（A）和 FastCGI+Nginx（D）两套 HTTP 接入方案。

**Architecture:** 分层架构：入口层（main_a / main_d）→ Handler → Service → DAO → libpq → PostgreSQL。A/D 方案共享全部业务代码（Handler/Service/DAO/Template/Config/Models），仅入口文件不同。

**Tech Stack:** C++11, libpq, cpp-httplib (v0.23+), libfcgi++, Google Test, Docker (CentOS 7.9), GNU Make

## Global Constraints

- C++ 标准：C++11 及以下，禁止使用 C++14/17/20 特性
- 命名规范：驼峰式（类/函数大驼峰，变量小驼峰，成员变量尾下划线 `_`）
- 注释和文档：统一使用中文
- 字符串使用双引号
- 文件后缀：`.cpp` / `.h`
- Google C++ Style Guide：2 空格缩进，每行 ≤80 字符，`nullptr` 替代 NULL
- 构建系统：GNU Make，`SCHEME=A|D` 切换方案
- 所有测试在 Docker 隔离环境中运行，不污染本地环境
- 禁止修改 `db/` 目录下的已有文件
- `config/secrets.h` 不纳入版本控制（如有）
- 数据库操作必须通过 DAO 层，禁止 Handler 直接操作数据库

---

## 文件地图

```
src/
├── models.h           # 数据结构定义（Student, Score, PivotRow, DbConfig）
├── config.h           # 配置读取接口
├── config.cpp         # 从环境变量读取 DB 连接信息
├── dao.h              # 数据访问层接口
├── dao.cpp            # libpq 直连 PostgreSQL，执行查询
├── service.h          # 业务逻辑层接口
├── service.cpp        # 班级列表 + 成绩透视查询
├── template.h         # HTML 模板渲染接口
├── template.cpp       # 生成完整 HTML 页面（深色科幻主题）
├── handler.h          # 请求处理器接口
├── handler.cpp        # 解析 HTTP 参数，调度 Service + Template
├── main_a.cpp         # A 方案入口（cpp-httplib）
└── main_d.cpp         # D 方案入口（FastCGI）

include/
└── httplib.h          # cpp-httplib 单头文件（vendored, v0.23+）

test/
├── Makefile           # 测试构建文件
├── test_config.cpp    # Config 模块测试
├── test_dao.cpp       # DAO 模块测试（需要 DB）
├── test_service.cpp   # Service 模块测试（需要 DB）
└── test_template.cpp  # Template 模块测试（纯逻辑）

Makefile               # 顶层构建（SCHEME=A|D 切换）
.gitignore
test.sh                # 集成测试脚本（curl 驱动）
```

依赖关系：

```
models.h  ←  config  ←  dao  ←  service  ←  template  ←  handler  ←  main_a
                                                                      ↖  main_d
```

---

### Task 1: 项目脚手架

**Files:**
- Create: `Makefile`
- Create: `test/Makefile`
- Create: `.gitignore`
- Create: `src/` (directory)
- Create: `include/` (directory)
- Create: `test/` (directory)
- Create: `build/` (directory, via Makefile)

**Interfaces:**
- Produces: `make SCHEME=A` 编译 `build/app_a`，`make SCHEME=D` 编译 `build/app_d`，`make clean` 清理

- [ ] **Step 1: 创建目录结构**

```bash
mkdir -p src include test build
```

- [ ] **Step 2: 创建 .gitignore**

```bash
cat > .gitignore << 'GITIGNORE'
build/
*.o
*.d
app_a
app_d
coverage.info
coverage_html/
.vscode/
*.swp
GITIGNORE
```

- [ ] **Step 3: 创建顶层 Makefile**

写入以下内容到 `Makefile`：

```makefile
# 构建方案: A (cpp-httplib) 或 D (FastCGI)
SCHEME ?= A

CXX      := g++
CXXFLAGS := -std=c++11 -Wall -Wextra -O2
LDFLAGS  := -lpq -lpthread

BUILD_DIR := build
TARGET    := $(BUILD_DIR)/app_a
SRCS      := src/handler.cpp src/service.cpp src/dao.cpp src/template.cpp src/config.cpp

# 头文件路径
INCLUDES  := -Isrc -Iinclude

ifeq ($(SCHEME), D)
  TARGET   := $(BUILD_DIR)/app_d
  SRCS     += src/main_d.cpp
  CXXFLAGS += -DBUILD_SCHEME_D
  LDFLAGS  += -lfcgi++
else
  SRCS     += src/main_a.cpp
endif

OBJS := $(SRCS:src/%.cpp=$(BUILD_DIR)/%.o)
DEPS := $(OBJS:.o=.d)

.PHONY: all clean

all: $(TARGET)

# 链接
$(TARGET): $(OBJS)
	@mkdir -p $(BUILD_DIR)
	$(CXX) $(CXXFLAGS) -o $@ $^ $(LDFLAGS)

# 编译（自动生成依赖文件）
$(BUILD_DIR)/%.o: src/%.cpp
	@mkdir -p $(BUILD_DIR)
	$(CXX) $(CXXFLAGS) $(INCLUDES) -MMD -MP -c $< -o $@

# Docker 环境中的单元测试（需要 PostgreSQL 可用）
# 仅在容器内使用，不要在本地直接调用
test: $(TARGET)
	cd test && make

# 清理
clean:
	rm -rf $(BUILD_DIR)
	cd test && make clean || true

# 引入自动生成的依赖
-include $(DEPS)
```

- [ ] **Step 4: 创建 test/Makefile**

写入以下内容到 `test/Makefile`：

```makefile
CXX      := g++
CXXFLAGS := -std=c++11 -Wall -Wextra -g -O0
LDFLAGS  := -lgtest -lgtest_main -lpq -lpthread

BUILD_DIR := ../build/test
INCLUDES  := -I../src -I../include

TEST_SRCS := $(wildcard *.cpp)
TEST_BINS := $(TEST_SRCS:%.cpp=$(BUILD_DIR)/%)

# 被测源文件（不含 main*.cpp）
SRC_OBJS  := $(BUILD_DIR)/handler.o $(BUILD_DIR)/service.o \
             $(BUILD_DIR)/dao.o $(BUILD_DIR)/template.o $(BUILD_DIR)/config.o

.PHONY: all clean

all: $(TEST_BINS)
	@for t in $(TEST_BINS); do echo "Running $$t..."; $$t || exit 1; done

$(BUILD_DIR)/%: %.cpp $(SRC_OBJS)
	@mkdir -p $(BUILD_DIR)
	$(CXX) $(CXXFLAGS) $(INCLUDES) -o $@ $< $(SRC_OBJS) $(LDFLAGS)

$(BUILD_DIR)/%.o: ../src/%.cpp
	@mkdir -p $(BUILD_DIR)
	$(CXX) $(CXXFLAGS) $(INCLUDES) -c $< -o $@

clean:
	rm -rf $(BUILD_DIR)
```

- [ ] **Step 5: 验证**

```bash
make SCHEME=A 2>&1 | head -5
# 预期: 无报错（虽然 src/*.cpp 不存在，但 Make 在链接阶段才报错）
# 实际会报 "No rule to make target 'src/handler.cpp'" — 这是预期行为，表示 Makefile 语法正确
```

---

### Task 2: 数据模型定义 (models.h)

**Files:**
- Create: `src/models.h`

**Interfaces:**
- Produces: `Student`, `Score`, `PivotRow`, `DbConfig` 四个结构体，被所有后续模块引用

- [ ] **Step 1: 创建 src/models.h**

```cpp
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
```

- [ ] **Step 2: 验证编译**

```bash
g++ -std=c++11 -Wall -Wextra -Isrc -fsyntax-only src/models.h
# 预期: 无输出（编译通过）
```

---

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

### Task 4: 数据访问层 (DAO)

**Files:**
- Create: `src/dao.h`
- Create: `src/dao.cpp`

**Interfaces:**
- Consumes: `DbConfig` from `config.h`, `PivotRow` from `models.h`
- Produces:
  - `bool ConnectDb(const DbConfig& config)` — 建立连接
  - `void DisconnectDb()` — 关闭连接
  - `std::vector<std::string> QueryClasses()` — 获取所有班级
  - `std::vector<PivotRow> QueryPivot(const std::string& classFilter)` — 透视查询

- [ ] **Step 1: 创建 src/dao.h**

```cpp
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
```

- [ ] **Step 2: 创建 src/dao.cpp**

```cpp
// 学生成绩管理系统 — 数据访问层实现
// 使用 libpq 参数化查询防止 SQL 注入

#include "dao.h"

#include <cstdlib>
#include <cstring>
#include <sstream>
#include <stdexcept>
#include <string>
#include <vector>

#include <libpq-fe.h>

namespace {

// 全局数据库连接（单连接模式）
PGconn* g_conn = nullptr;

// 科目列表（应用常量，与 PHP 版保持一致）
const char* kSubjects[] = {"语文", "数学", "英语", "科学"};
const int kSubjectCount = 4;

// 将 PGresult 中的值安全转为字符串
std::string GetString(PGresult* res, int row, int col) {
  if (PQgetisnull(res, row, col)) {
    return "";
  }
  return std::string(PQgetvalue(res, row, col));
}

}  // namespace

bool ConnectDb(const DbConfig& config) {
  std::ostringstream connStr;
  connStr << "host=" << config.host
          << " port=" << config.port
          << " dbname=" << config.dbName
          << " user=" << config.user
          << " password=" << config.password;

  g_conn = PQconnectdb(connStr.str().c_str());
  return PQstatus(g_conn) == CONNECTION_OK;
}

void DisconnectDb() {
  if (g_conn != nullptr) {
    PQfinish(g_conn);
    g_conn = nullptr;
  }
}

std::vector<std::string> QueryClasses() {
  std::vector<std::string> classes;
  if (g_conn == nullptr) return classes;

  PGresult* res = PQexec(g_conn,
      "SELECT DISTINCT class FROM students ORDER BY class");
  if (PQresultStatus(res) != PGRES_TUPLES_OK) {
    PQclear(res);
    return classes;
  }

  int rows = PQntuples(res);
  for (int i = 0; i < rows; ++i) {
    classes.push_back(GetString(res, i, 0));
  }
  PQclear(res);
  return classes;
}

std::vector<PivotRow> QueryPivot(const std::string& classFilter) {
  std::vector<PivotRow> rows;
  if (g_conn == nullptr) return rows;

  // 构建透视查询 SQL
  // 使用 $1 参数化班级筛选，应用常量科目名通过反引号拼接
  std::ostringstream sql;
  sql << "SELECT s.id, s.name, s.class";
  for (int i = 0; i < kSubjectCount; ++i) {
    sql << ", MAX(CASE WHEN sc.subject = '"
        << kSubjects[i]
        << "' THEN sc.score END) AS \"subject_" << i << "\"";
  }
  sql << " FROM students s"
      << " LEFT JOIN scores sc ON s.id = sc.student_id";

  if (!classFilter.empty()) {
    sql << " WHERE s.class = $1";
  }
  sql << " GROUP BY s.id, s.name, s.class"
      << " ORDER BY s.class, s.name";

  // 准备参数
  const char* paramValues[1] = {nullptr};
  if (!classFilter.empty()) {
    paramValues[0] = classFilter.c_str();
  }

  PGresult* res = PQexecParams(
      g_conn,
      sql.str().c_str(),
      classFilter.empty() ? 0 : 1,  // 参数个数
      nullptr,                        // 参数类型（让 PG 推断）
      paramValues,
      nullptr,                        // 参数长度（字符串自动）
      nullptr,                        // 参数格式（文本）
      0                               // 结果格式（文本）
  );

  if (PQresultStatus(res) != PGRES_TUPLES_OK) {
    PQclear(res);
    return rows;
  }

  int rowCount = PQntuples(res);
  for (int r = 0; r < rowCount; ++r) {
    PivotRow row;
    row.studentId   = std::atoi(GetString(res, r, 0).c_str());
    row.studentName = GetString(res, r, 1);
    row.className   = GetString(res, r, 2);

    // 各科成绩（从第 3 列开始）
    for (int i = 0; i < kSubjectCount; ++i) {
      if (!PQgetisnull(res, r, 3 + i)) {
        double score = std::atof(PQgetvalue(res, r, 3 + i));
        row.scores[kSubjects[i]] = score;
      }
      // NULL 的科目不插入 map，Template 层据此显示 "-"
    }
    rows.push_back(row);
  }
  PQclear(res);
  return rows;
}
```

- [ ] **Step 3: 验证编译**

```bash
g++ -std=c++11 -Wall -Wextra -Isrc -c src/dao.cpp -o build/dao.o
# 预期: 编译成功（可能需要 -I/path/to/libpq，Docker 中为 /usr/include）
# 本地如果 libpq-fe.h 不在标准路径，用:
# g++ -std=c++11 -Wall -Wextra -Isrc $(pg_config --includedir) -c src/dao.cpp -o build/dao.o
```

---

### Task 5: 业务逻辑层 (Service)

**Files:**
- Create: `src/service.h`
- Create: `src/service.cpp`

**Interfaces:**
- Consumes: `PivotRow` from `models.h`, `QueryClasses()` / `QueryPivot()` from `dao.h`
- Produces:
  - `std::vector<std::string> GetClasses()` — 获取所有班级
  - `std::vector<PivotRow> GetStudentScores(const std::string& classFilter)` — 获取成绩

- [ ] **Step 1: 创建 src/service.h**

```cpp
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
```

- [ ] **Step 2: 创建 src/service.cpp**

```cpp
// 学生成绩管理系统 — 业务逻辑层实现

#include "service.h"

#include "dao.h"

std::vector<std::string> GetClasses() {
  return QueryClasses();
}

std::vector<PivotRow> GetStudentScores(const std::string& classFilter) {
  return QueryPivot(classFilter);
}
```

- [ ] **Step 3: 验证编译**

```bash
g++ -std=c++11 -Wall -Wextra -Isrc -c src/service.cpp -o build/service.o
# 预期: 编译成功
```

---

### Task 6: HTML 模板渲染 (Template)

**Files:**
- Create: `src/template.h`
- Create: `src/template.cpp`

**Interfaces:**
- Consumes: `PivotRow` from `models.h`
- Produces: `std::string RenderPage(const std::vector<std::string>& classes, const std::vector<PivotRow>& rows, const std::string& selectedClass)` — 渲染完整 HTML 页面

- [ ] **Step 1: 创建 src/template.h**

```cpp
// 学生成绩管理系统 — HTML 模板渲染
// 渲染成绩透视表页面，完全复刻现有深色科幻主题样式

#ifndef SRC_TEMPLATE_H_
#define SRC_TEMPLATE_H_

#include <string>
#include <vector>

#include "models.h"

// 渲染完整 HTML 页面
// classes: 班级列表（用于下拉框）
// rows: 成绩透视数据
// selectedClass: 当前筛选的班级（空字符串表示全部）
std::string RenderPage(
    const std::vector<std::string>& classes,
    const std::vector<PivotRow>& rows,
    const std::string& selectedClass);

#endif  // SRC_TEMPLATE_H_
```

- [ ] **Step 2: 创建 src/template.cpp**

```cpp
// 学生成绩管理系统 — HTML 模板渲染实现
// 深色科幻主题，完全复刻现有 PHP 版样式

#include "template.h"

#include <sstream>
#include <string>
#include <vector>

#include "models.h"

namespace {

// 科目列表（与 PHP 版一致）
const char* kSubjects[] = {"语文", "数学", "英语", "科学"};
const int kSubjectCount = 4;

// HTML 转义
std::string EscapeHtml(const std::string& text) {
  std::ostringstream out;
  for (size_t i = 0; i < text.size(); ++i) {
    switch (text[i]) {
      case '&':  out << "&amp;";  break;
      case '<':  out << "&lt;";   break;
      case '>':  out << "&gt;";   break;
      case '"':  out << "&quot;"; break;
      case '\'': out << "&#39;";  break;
      default:   out << text[i];  break;
    }
  }
  return out.str();
}

// 格式化分数显示
std::string FormatScore(const std::map<std::string, double>& scores,
                        const std::string& subject) {
  std::map<std::string, double>::const_iterator it = scores.find(subject);
  if (it == scores.end()) {
    return "-";
  }
  // 去掉多余的 .00 尾部
  std::ostringstream oss;
  double val = it->second;
  if (val == static_cast<int>(val)) {
    oss << static_cast<int>(val);
  } else {
    oss << val;
  }
  return oss.str();
}

// 渲染班级下拉框
std::string RenderClassSelect(const std::vector<std::string>& classes,
                              const std::string& selectedClass) {
  std::ostringstream html;
  html << "<form method=\"GET\" class=\"filter-bar\">\n"
       << "  <label>班级筛选：</label>\n"
       << "  <select name=\"class\" onchange=\"this.form.submit()\">\n"
       << "    <option value=\"\">全部班级</option>\n";

  for (size_t i = 0; i < classes.size(); ++i) {
    html << "    <option value=\"" << EscapeHtml(classes[i]) << "\"";
    if (classes[i] == selectedClass) {
      html << " selected";
    }
    html << ">" << EscapeHtml(classes[i]) << "</option>\n";
  }

  html << "  </select>\n"
       << "  <button type=\"submit\">筛选</button>\n"
       << "</form>\n";
  return html.str();
}

// 渲染成绩表格
std::string RenderTable(const std::vector<PivotRow>& rows) {
  if (rows.empty()) {
    return "<div class=\"empty-state\">暂无成绩数据</div>\n";
  }

  std::ostringstream html;
  html << "<table>\n"
       << "  <thead>\n"
       << "    <tr>\n"
       << "      <th>姓名</th>\n"
       << "      <th>班级</th>\n";

  for (int i = 0; i < kSubjectCount; ++i) {
    html << "      <th>" << kSubjects[i] << "</th>\n";
  }

  html << "    </tr>\n"
       << "  </thead>\n"
       << "  <tbody>\n";

  for (size_t i = 0; i < rows.size(); ++i) {
    const PivotRow& row = rows[i];
    html << "    <tr>\n"
         << "      <td>" << EscapeHtml(row.studentName) << "</td>\n"
         << "      <td>" << EscapeHtml(row.className) << "</td>\n";

    for (int s = 0; s < kSubjectCount; ++s) {
      html << "      <td>"
           << EscapeHtml(FormatScore(row.scores, kSubjects[s]))
           << "</td>\n";
    }

    html << "    </tr>\n";
  }

  html << "  </tbody>\n"
       << "</table>\n";
  return html.str();
}

}  // namespace

std::string RenderPage(
    const std::vector<std::string>& classes,
    const std::vector<PivotRow>& rows,
    const std::string& selectedClass) {

  // 这里需要完整输出 CSS + HTML 结构
  // 由于 CSS 约 150 行，在模板中直接内联
  // 以下为完整 HTML 页面结构
  std::ostringstream html;
  html << "<!DOCTYPE html>\n"
       << "<html lang=\"zh-CN\">\n"
       << "<head>\n"
       << "  <meta charset=\"UTF-8\">\n"
       << "  <title>教育成绩数据分析平台</title>\n"
       << "  <style>\n"
       // 复用 PHP 版全部 CSS（约 150 行）
       // 这里因篇幅限制只列关键样式，实际实现需完整复制
       << "    *,*::before,*::after{box-sizing:border-box;margin:0;padding:0;}\n"
       << "    body{font-family:-apple-system,BlinkMacSystemFont,\"Segoe UI\",Roboto,\"Noto Sans SC\",sans-serif;color:#e2e8f0;line-height:1.6;min-height:100vh;background:#0a0e27;overflow-x:hidden;}\n"
       << "    body::before,body::after{content:'';position:fixed;border-radius:50%;filter:blur(120px);z-index:0;animation:orbFloat 12s ease-in-out infinite alternate;}\n"
       << "    body::before{width:600px;height:600px;background:radial-gradient(circle,rgba(59,130,246,.35) 0%,transparent 70%);top:-150px;left:-100px;}\n"
       << "    body::after{width:500px;height:500px;background:radial-gradient(circle,rgba(139,92,246,.3) 0%,transparent 70%);bottom:-100px;right:-80px;animation-delay:-6s;}\n"
       << "    @keyframes orbFloat{0%{transform:translate(0,0) scale(1);}50%{transform:translate(60px,-40px) scale(1.25);}100%{transform:translate(-30px,30px) scale(1.1);}}\n"
       << "    .grid-bg{position:fixed;inset:0;z-index:0;opacity:.06;pointer-events:none;background-image:linear-gradient(rgba(59,130,246,.5) 1px,transparent 1px),linear-gradient(90deg,rgba(59,130,246,.5) 1px,transparent 1px);background-size:60px 60px;animation:gridPulse 8s ease-in-out infinite alternate;}\n"
       << "    @keyframes gridPulse{0%{opacity:.04;}100%{opacity:.1;}}\n"
       << "    .globe-wrap{position:fixed;z-index:0;pointer-events:none;top:50%;left:50%;transform:translate(-50%,-50%);width:500px;height:500px;}\n"
       << "    .globe{position:absolute;inset:20px;border-radius:50%;background:radial-gradient(circle at 35% 35%,rgba(59,130,246,.15) 0%,transparent 50%),radial-gradient(circle at 50% 50%,rgba(16,185,129,.08) 0%,transparent 70%);box-shadow:inset 0 0 80px rgba(59,130,246,.12),0 0 60px rgba(37,99,235,.15),0 0 120px rgba(37,99,235,.06);animation:globePulse 6s ease-in-out infinite alternate;}\n"
       << "    .globe::before{content:'';position:absolute;inset:0;border-radius:50%;background:radial-gradient(ellipse 80% 2px at 50% 25%,transparent 49%,rgba(59,130,246,.25) 50%,transparent 51%),radial-gradient(ellipse 90% 2px at 50% 50%,transparent 49%,rgba(59,130,246,.2) 50%,transparent 51%),radial-gradient(ellipse 80% 2px at 50% 75%,transparent 49%,rgba(59,130,246,.15) 50%,transparent 51%);}\n"
       << "    .globe::after{content:'';position:absolute;inset:0;border-radius:50%;background:linear-gradient(90deg,transparent 49.5%,rgba(59,130,246,.15) 50%,transparent 50.5%),linear-gradient(150deg,transparent 49.5%,rgba(59,130,246,.1) 50%,transparent 50.5%),linear-gradient(30deg,transparent 49.5%,rgba(59,130,246,.1) 50%,transparent 50.5%);}\n"
       << "    .ring{position:absolute;border-radius:50%;pointer-events:none;}\n"
       << "    .ring-1{inset:-30px;border:1px solid rgba(59,130,246,.12);animation:ringSpin1 20s linear infinite;clip-path:polygon(0 0,100% 0,100% 60%,0 60%);}\n"
       << "    .ring-2{inset:-50px;border:1px solid rgba(139,92,246,.08);transform:rotateX(70deg);animation:ringSpin2 25s linear infinite;}\n"
       << "    .ring-3{inset:-15px;border:1px solid rgba(16,185,129,.1);transform:rotateY(60deg);animation:ringSpin3 18s linear infinite;}\n"
       << "    .ring-1::after{content:'';position:absolute;width:6px;height:6px;background:rgba(96,165,250,.8);border-radius:50%;top:-3px;left:50%;box-shadow:0 0 8px rgba(59,130,246,.6);}\n"
       << "    @keyframes globePulse{0%{box-shadow:inset 0 0 80px rgba(59,130,246,.12),0 0 60px rgba(37,99,235,.15),0 0 120px rgba(37,99,235,.06);}100%{box-shadow:inset 0 0 100px rgba(59,130,246,.18),0 0 80px rgba(37,99,235,.2),0 0 160px rgba(37,99,235,.1);}}\n"
       << "    @keyframes ringSpin1{0%{transform:rotateX(75deg) rotateZ(0deg);}100%{transform:rotateX(75deg) rotateZ(360deg);}}\n"
       << "    @keyframes ringSpin2{0%{transform:rotateX(70deg) rotateZ(0deg);}100%{transform:rotateX(70deg) rotateZ(-360deg);}}\n"
       << "    @keyframes ringSpin3{0%{transform:rotateY(60deg) rotateZ(0deg);}100%{transform:rotateY(60deg) rotateZ(360deg);}}\n"
       << "    .header{position:relative;z-index:1;background:rgba(15,23,42,.75);backdrop-filter:blur(16px);color:#e2e8f0;padding:24px 0;text-align:center;box-shadow:0 1px 0 rgba(59,130,246,.15),0 4px 24px rgba(0,0,0,.3);border-bottom:1px solid rgba(59,130,246,.1);}\n"
       << "    .header h1{font-size:1.5rem;font-weight:500;letter-spacing:.06em;}\n"
       << "    .container{position:relative;z-index:1;max-width:960px;margin:0 auto;padding:28px 20px;}\n"
       << "    .filter-bar{background:rgba(15,23,42,.85);backdrop-filter:blur(12px);border-radius:10px;padding:16px 20px;margin-bottom:20px;display:flex;align-items:center;gap:10px;box-shadow:0 4px 16px rgba(0,0,0,.3);border:1px solid rgba(59,130,246,.15);}\n"
       << "    .filter-bar label{font-weight:500;white-space:nowrap;color:#94a3b8;}\n"
       << "    .filter-bar select{flex:1;max-width:220px;padding:8px 12px;border:1px solid rgba(59,130,246,.3);border-radius:6px;font-size:.95rem;background:rgba(30,41,59,.8);color:#e2e8f0;}\n"
       << "    .filter-bar button{padding:8px 20px;background:linear-gradient(135deg,#2563eb,#3b82f6);color:#fff;border:none;border-radius:6px;font-size:.95rem;cursor:pointer;transition:all .2s;box-shadow:0 2px 8px rgba(37,99,235,.3);}\n"
       << "    .filter-bar button:hover{background:linear-gradient(135deg,#1d4ed8,#2563eb);transform:translateY(-1px);box-shadow:0 4px 16px rgba(37,99,235,.4);}\n"
       << "    .empty-state{text-align:center;padding:60px 20px;color:#64748b;font-size:1.1rem;}\n"
       << "    table{width:100%;border-collapse:collapse;background:rgba(15,23,42,.85);backdrop-filter:blur(12px);border-radius:10px;overflow:hidden;box-shadow:0 4px 24px rgba(0,0,0,.3);border:1px solid rgba(59,130,246,.12);}\n"
       << "    thead{background:linear-gradient(135deg,rgba(30,58,138,.95),rgba(37,99,235,.85));color:#fff;}\n"
       << "    th{padding:14px 18px;text-align:left;font-weight:500;font-size:.9rem;letter-spacing:.03em;text-transform:uppercase;}\n"
       << "    td{padding:12px 18px;border-bottom:1px solid rgba(59,130,246,.08);color:#cbd5e1;}\n"
       << "    tbody tr{transition:background .2s;}\n"
       << "    tbody tr:nth-child(even){background:rgba(30,41,59,.4);}\n"
       << "    tbody tr:hover{background:rgba(37,99,235,.15);}\n"
       << "    tbody td:first-child{font-weight:500;color:#e2e8f0;}\n"
       << "    tbody td:not(:first-child):not(:nth-child(2)){text-align:center;font-variant-numeric:tabular-nums;}\n"
       << "  </style>\n"
       << "</head>\n"
       << "<body>\n"
       << "  <div class=\"grid-bg\"></div>\n"
       << "  <div class=\"globe-wrap\">\n"
       << "    <div class=\"globe\"></div>\n"
       << "    <div class=\"ring ring-1\"></div>\n"
       << "    <div class=\"ring ring-2\"></div>\n"
       << "    <div class=\"ring ring-3\"></div>\n"
       << "  </div>\n"
       << "  <div class=\"header\"><h1>教育成绩数据分析平台</h1></div>\n"
       << "  <div class=\"container\">\n"
       << RenderClassSelect(classes, selectedClass)
       << RenderTable(rows)
       << "  </div>\n"
       << "</body>\n"
       << "</html>\n";

  return html.str();
}
```

- [ ] **Step 3: 验证编译**

```bash
g++ -std=c++11 -Wall -Wextra -Isrc -c src/template.cpp -o build/template.o
# 预期: 编译成功
```

---

### Task 7: 请求处理器 (Handler)

**Files:**
- Create: `src/handler.h`
- Create: `src/handler.cpp`

**Interfaces:**
- Consumes: `PivotRow` from `models.h`, `GetClasses()` / `GetStudentScores()` from `service.h`, `RenderPage()` from `template.h`
- Produces: `std::string HandleIndex(const std::string& classFilter)` — 处理 GET / 请求，返回完整 HTML

- [ ] **Step 1: 创建 src/handler.h**

```cpp
// 学生成绩管理系统 — 请求处理器
// 解析 HTTP 参数，调度 Service 和 Template

#ifndef SRC_HANDLER_H_
#define SRC_HANDLER_H_

#include <string>

// 处理首页请求
// classFilter: URL 中的 class 查询参数（已 URL 解码）
// 返回完整的 HTML 响应体
std::string HandleIndex(const std::string& classFilter);

#endif  // SRC_HANDLER_H_
```

- [ ] **Step 2: 创建 src/handler.cpp**

```cpp
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
```

- [ ] **Step 3: 验证编译**

```bash
g++ -std=c++11 -Wall -Wextra -Isrc -c src/handler.cpp -o build/handler.o
# 预期: 编译成功
```

---

### Task 8: A 方案入口 (main_a.cpp)

**Files:**
- Create: `src/main_a.cpp`
- Download: `include/httplib.h` (从 GitHub 下载 cpp-httplib v0.23.0)

**Interfaces:**
- Consumes: `LoadDbConfig()` from `config.h`, `ConnectDb()` / `DisconnectDb()` from `dao.h`, `HandleIndex()` from `handler.h`, `DbConfig` from `models.h`
- Produces: 独立可执行文件 `build/app_a`

- [ ] **Step 1: 下载 cpp-httplib**

```bash
curl -fsSL -o include/httplib.h \
  https://raw.githubusercontent.com/yhirose/cpp-httplib/v0.23.0/httplib.h
```

- [ ] **Step 2: 创建 src/main_a.cpp**

```cpp
// 学生成绩管理系统 — A 方案入口（cpp-httplib 独立 HTTP 服务）
// 直接监听 HTTP 端口，不需要 Nginx

#include <cstdlib>
#include <iostream>
#include <string>

#include "config.h"
#include "dao.h"
#include "handler.h"
#include "httplib.h"
#include "models.h"

namespace {

// 从 URL 查询字符串中提取 class 参数值
std::string ParseClassParam(const std::string& query) {
  const std::string key = "class=";
  size_t pos = query.find(key);
  if (pos == std::string::npos) return "";
  pos += key.size();
  size_t end = query.find('&', pos);
  return query.substr(pos, end == std::string::npos ? end : end - pos);
}

}  // namespace

int main() {
  // 加载配置
  DbConfig config = LoadDbConfig();

  // 连接数据库
  std::cerr << "[main_a] 正在连接数据库 " << config.host << "...\n";
  if (!ConnectDb(config)) {
    std::cerr << "[main_a] 数据库连接失败，请检查配置\n";
    return 1;
  }
  std::cerr << "[main_a] 数据库连接成功\n";

  // 读取 HTTP 端口
  const char* portStr = std::getenv("HTTP_PORT");
  int port = 8080;
  if (portStr != nullptr && portStr[0] != '\0') {
    port = std::atoi(portStr);
  }

  // 创建 HTTP 服务器
  httplib::Server svr;

  // 注册路由: GET /
  svr.Get("/", [](const httplib::Request& req, httplib::Response& res) {
    // 解析 class 参数（cpp-httplib 已做 URL 解码）
    std::string classFilter;
    if (req.has_param("class")) {
      classFilter = req.get_param_value("class");
    }

    // 处理请求
    std::string html = HandleIndex(classFilter);

    // 设置响应
    res.set_content(html, "text/html; charset=UTF-8");
  });

  // 启动服务
  std::cerr << "[main_a] 服务已启动: http://0.0.0.0:" << port << "\n";
  svr.listen("0.0.0.0", port);

  // 清理
  DisconnectDb();
  return 0;
}
```

- [ ] **Step 3: 编译链接**

```bash
make SCHEME=A -j$(nproc)
# 预期: build/app_a 生成成功
```

- [ ] **Step 4: 验证二进制**

```bash
file build/app_a
# 预期: ELF 64-bit executable
ldd build/app_a
# 预期: 依赖 libpq.so, libpthread.so, libstdc++.so（无未解析符号）
```

---

### Task 9: D 方案入口 (main_d.cpp)

**Files:**
- Create: `src/main_d.cpp`

**Interfaces:**
- Consumes: 同 Task 8，但使用 FastCGI 协议
- Produces: 独立可执行文件 `build/app_d`

- [ ] **Step 1: 创建 src/main_d.cpp**

```cpp
// 学生成绩管理系统 — D 方案入口（FastCGI + Nginx）
// 通过 FastCGI 协议与 Nginx 通信，复用现有前端架构

#include <cstdlib>
#include <iostream>
#include <string>

#include "config.h"
#include "dao.h"
#include "handler.h"
#include "models.h"

#ifdef BUILD_SCHEME_D
#include <fcgio.h>

namespace {

// 解析 FastCGI QUERY_STRING 中的 class 参数
std::string ParseClassParam(const char* queryString) {
  if (queryString == nullptr) return "";
  const std::string query(queryString);
  const std::string key = "class=";
  size_t pos = query.find(key);
  if (pos == std::string::npos) return "";
  pos += key.size();
  size_t end = query.find('&', pos);
  return query.substr(pos, end == std::string::npos ? end : end - pos);
}

}  // namespace

int main() {
  // 加载配置
  DbConfig config = LoadDbConfig();

  // 连接数据库
  std::cerr << "[main_d] 正在连接数据库 " << config.host << "...\n";
  if (!ConnectDb(config)) {
    std::cerr << "[main_d] 数据库连接失败，请检查配置\n";
    return 1;
  }
  std::cerr << "[main_d] 数据库连接成功\n";

  // 初始化 FastCGI
  FCGX_Request request;
  FCGX_Init();
  FCGX_InitRequest(&request, 0, 0);

  std::cerr << "[main_d] FastCGI 服务已启动，等待请求...\n";

  // Accept 循环
  while (FCGX_Accept_r(&request) == 0) {
    // 解析 class 查询参数
    const char* queryString = FCGX_GetParam("QUERY_STRING", request.envp);
    std::string classFilter = ParseClassParam(queryString);

    // 处理请求
    std::string html = HandleIndex(classFilter);

    // 输出 HTTP 响应
    FCGX_FPrintF(request.out,
        "Content-Type: text/html; charset=UTF-8\r\n"
        "Content-Length: %zu\r\n"
        "\r\n"
        "%s",
        html.size(), html.c_str());
  }

  // 清理
  DisconnectDb();
  return 0;
}
#else
// 非 D 方案编译时提供占位 main，防止链接报错
int main() {
  std::cerr << "Error: D scheme not enabled. Use 'make SCHEME=D'.\n";
  return 1;
}
#endif  // BUILD_SCHEME_D
```

- [ ] **Step 2: 编译链接**

```bash
make SCHEME=D -j$(nproc)
# 预期: build/app_d 生成成功
```

- [ ] **Step 3: 验证二进制**

```bash
file build/app_d
# 预期: ELF 64-bit executable
ldd build/app_d
# 预期: 依赖 libpq.so, libfcgi++.so, libpthread.so, libstdc++.so
```

---

### Task 10: 单元测试

**Files:**
- Create: `test/test_service.cpp`
- Create: `test/test_dao.cpp`
- Create: `test/test_template.cpp`
- `test/test_config.cpp` 已在 Task 3 创建

**Interfaces:**
- Consumes: 所有 src/ 模块
- Produces: 4 个测试二进制文件

- [ ] **Step 1: 创建 test/test_service.cpp**

```cpp
// 学生成绩管理系统 — Service 模块测试
// 需要 PostgreSQL 数据库连接（在 Docker 测试容器中运行）

#include <gtest/gtest.h>

#include "config.h"
#include "dao.h"
#include "service.h"

class ServiceTest : public ::testing::Test {
 protected:
  void SetUp() override {
    DbConfig cfg = LoadDbConfig();
    ASSERT_TRUE(ConnectDb(cfg));
  }

  void TearDown() override {
    DisconnectDb();
  }
};

// TC-S01: 获取所有不重复班级
TEST_F(ServiceTest, GetClassesReturnsAllDistinctClasses) {
  std::vector<std::string> classes = GetClasses();
  ASSERT_GE(classes.size(), 1u);
  // 验证排序
  for (size_t i = 1; i < classes.size(); ++i) {
    ASSERT_LE(classes[i - 1], classes[i]);
  }
}

// TC-S02: 无筛选条件 — 全部学生
TEST_F(ServiceTest, GetStudentScoresReturnsAllStudentsWhenNoFilter) {
  std::vector<PivotRow> rows = GetStudentScores("");
  ASSERT_GE(rows.size(), 1u);
  // 验证排序: class ASC, name ASC
  for (size_t i = 1; i < rows.size(); ++i) {
    ASSERT_TRUE(
        rows[i - 1].className < rows[i].className ||
        (rows[i - 1].className == rows[i].className &&
         rows[i - 1].studentName <= rows[i].studentName)
    );
  }
}

// TC-S03: 按班级筛选
TEST_F(ServiceTest, GetStudentScoresFiltersByClass) {
  std::vector<std::string> classes = GetClasses();
  if (classes.empty()) {
    GTEST_SKIP() << "无班级数据";
  }
  std::string targetClass = classes[0];

  std::vector<PivotRow> rows = GetStudentScores(targetClass);
  for (size_t i = 0; i < rows.size(); ++i) {
    EXPECT_EQ(rows[i].className, targetClass);
  }
}

// TC-S04: 筛选不存在的班级
TEST_F(ServiceTest, GetStudentScoresReturnsEmptyForNonexistentClass) {
  std::vector<PivotRow> rows = GetStudentScores("不存在的班级_xyz");
  EXPECT_TRUE(rows.empty());
}
```

- [ ] **Step 2: 创建 test/test_template.cpp**

```cpp
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
```

- [ ] **Step 3: 创建 test/test_dao.cpp**

```cpp
// 学生成绩管理系统 — DAO 模块测试
// 需要 PostgreSQL 数据库连接

#include <gtest/gtest.h>

#include <string>
#include <vector>

#include "config.h"
#include "dao.h"
#include "models.h"

class DaoTest : public ::testing::Test {
 protected:
  void SetUp() override {
    DbConfig cfg = LoadDbConfig();
    ASSERT_TRUE(ConnectDb(cfg));
  }

  void TearDown() override {
    DisconnectDb();
  }
};

// TC-D01: 数据库连接成功
TEST_F(DaoTest, ConnectsSuccessfully) {
  // 连接已在 SetUp 中验证
  SUCCEED();
}

// TC-D02: QueryClasses 返回结果
TEST_F(DaoTest, QueryClassesReturnsResults) {
  std::vector<std::string> classes = QueryClasses();
  ASSERT_GE(classes.size(), 1u);
  EXPECT_NE(classes[0], "");
}

// TC-D03: 参数化查询防止 SQL 注入
TEST_F(DaoTest, PreventsSqlInjection) {
  std::vector<PivotRow> rows = QueryPivot("'; DROP TABLE students; --");
  EXPECT_TRUE(rows.empty());
  // 验证表结构完好
  std::vector<std::string> classes = QueryClasses();
  ASSERT_GE(classes.size(), 1u);
}

// TC-D04: QueryPivot 包含分数
TEST_F(DaoTest, QueryPivotIncludesScores) {
  std::vector<PivotRow> rows = QueryPivot("");
  if (rows.empty()) {
    GTEST_SKIP() << "无数据";
  }
  // 至少有一个学生有分数
  bool hasScore = false;
  for (size_t i = 0; i < rows.size() && !hasScore; ++i) {
    hasScore = !rows[i].scores.empty();
  }
  EXPECT_TRUE(hasScore);
}
```

- [ ] **Step 4: 本地语法编译验证**

```bash
# 验证所有 .cpp 文件可编译（不链接，不运行）
for f in test/test_*.cpp; do
  echo "检查 $f ..."
  g++ -std=c++11 -Wall -Wextra -Isrc -I/usr/include -fsyntax-only "$f"
done
# 预期: 全部通过（如果本地没有 gtest 头文件，此步在 Docker 中执行）
```

---

### Task 11: Docker 容器化部署

**Files:**
- Create: `Dockerfile.a`
- Create: `Dockerfile.d`
- Create: `Dockerfile.test`
- Create: `docker-compose.a.yml`
- Create: `docker-compose.d.yml`
- Create: `docker-compose.test.yml`
- Create: `nginx/default.conf`
- Create: `supervisord.conf`

- [ ] **Step 1: 创建 Dockerfile.a**

```dockerfile
FROM centos:7.9.2009

# 切换至 CentOS Vault 镜像源（官方镜像站已下线）
RUN sed -i 's/mirrorlist/#mirrorlist/g' /etc/yum.repos.d/CentOS-*.repo && \
    sed -i 's|#baseurl=http://mirror.centos.org|baseurl=http://vault.centos.org|g' /etc/yum.repos.d/CentOS-*.repo

# 安装 EPEL + 编译工具链
RUN yum install -y epel-release && \
    sed -i 's/mirrorlist/#mirrorlist/g' /etc/yum.repos.d/epel*.repo && \
    sed -i 's|#baseurl|baseurl|g' /etc/yum.repos.d/epel*.repo && \
    sed -i 's|download.fedoraproject.org/pub|archives.fedoraproject.org/pub/archive|g' /etc/yum.repos.d/epel*.repo && \
    yum install -y \
    gcc-c++ make \
    postgresql-devel \
    && yum clean all

# 下载 cpp-httplib
RUN curl -fsSL -o /usr/local/include/httplib.h \
    https://raw.githubusercontent.com/yhirose/cpp-httplib/v0.23.0/httplib.h

WORKDIR /app
COPY . .

# 编译 A 方案
RUN make SCHEME=A -j$(nproc)

EXPOSE 8080

CMD ["./build/app_a"]
```

- [ ] **Step 2: 创建 Dockerfile.d**

```dockerfile
FROM centos:7.9.2009

# 切换至 CentOS Vault 镜像源
RUN sed -i 's/mirrorlist/#mirrorlist/g' /etc/yum.repos.d/CentOS-*.repo && \
    sed -i 's|#baseurl=http://mirror.centos.org|baseurl=http://vault.centos.org|g' /etc/yum.repos.d/CentOS-*.repo

# 安装 EPEL + nginx + FastCGI + 编译工具链
RUN yum install -y epel-release && \
    sed -i 's/mirrorlist/#mirrorlist/g' /etc/yum.repos.d/epel*.repo && \
    sed -i 's|#baseurl|baseurl|g' /etc/yum.repos.d/epel*.repo && \
    sed -i 's|download.fedoraproject.org/pub|archives.fedoraproject.org/pub/archive|g' /etc/yum.repos.d/epel*.repo && \
    yum install -y \
    gcc-c++ make \
    postgresql-devel \
    fcgi-devel spawn-fcgi \
    nginx supervisor \
    && yum clean all

WORKDIR /app
COPY . .

# 编译 D 方案
RUN make SCHEME=D -j$(nproc)

# 复制 Nginx 配置
COPY nginx/default.conf /etc/nginx/conf.d/default.conf

# 复制 Supervisor 配置
COPY supervisord.conf /etc/supervisord.conf

EXPOSE 80

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisord.conf"]
```

- [ ] **Step 3: 创建 Dockerfile.test**

```dockerfile
FROM centos:7.9.2009

# 切换至 CentOS Vault 镜像源
RUN sed -i 's/mirrorlist/#mirrorlist/g' /etc/yum.repos.d/CentOS-*.repo && \
    sed -i 's|#baseurl=http://mirror.centos.org|baseurl=http://vault.centos.org|g' /etc/yum.repos.d/CentOS-*.repo

# 安装 EPEL + 编译工具 + 测试依赖
RUN yum install -y epel-release && \
    sed -i 's/mirrorlist/#mirrorlist/g' /etc/yum.repos.d/epel*.repo && \
    sed -i 's|#baseurl|baseurl|g' /etc/yum.repos.d/epel*.repo && \
    sed -i 's|download.fedoraproject.org/pub|archives.fedoraproject.org/pub/archive|g' /etc/yum.repos.d/epel*.repo && \
    yum install -y \
    gcc-c++ make \
    postgresql-devel \
    lcov \
    && yum clean all

# 从源码编译 Google Test（CentOS 7 无预编译包）
RUN curl -fsSL -o /tmp/googletest.tar.gz \
    https://github.com/google/googletest/archive/refs/tags/v1.10.x.tar.gz && \
    cd /tmp && tar xf googletest.tar.gz && \
    cd googletest-1.10.x && \
    g++ -std=c++11 -isystem googletest/include -Igoogletest \
        -pthread -c googletest/src/gtest-all.cc -o gtest-all.o && \
    ar rcs /usr/lib/libgtest.a gtest-all.o && \
    g++ -std=c++11 -isystem googletest/include -Igoogletest \
        -pthread -c googletest/src/gtest_main.cc -o gtest_main.o && \
    ar rcs /usr/lib/libgtest_main.a gtest_main.o && \
    mkdir -p /usr/include/gtest && \
    cp -r googletest/include/gtest/* /usr/include/gtest/ && \
    rm -rf /tmp/googletest*

# 下载 cpp-httplib（A 方案编译需要）
RUN curl -fsSL -o /usr/local/include/httplib.h \
    https://raw.githubusercontent.com/yhirose/cpp-httplib/v0.23.0/httplib.h

ARG COVERAGE=0
ENV ENABLE_COVERAGE=${COVERAGE}

WORKDIR /app
COPY . .

# 构建并运行测试
CMD if [ "${ENABLE_COVERAGE}" = "1" ]; then \
      make CXXFLAGS="-std=c++11 -Wall -Wextra -g -O0 --coverage" \
           LDFLAGS="-lpq -lpthread -lgtest -lgtest_main --coverage" test ; \
      lcov --capture --directory . --output-file coverage.info ; \
      genhtml coverage.info --output-directory coverage_html ; \
    else \
      make test ; \
    fi
```

- [ ] **Step 4: 创建 docker-compose.a.yml**

```yaml
version: "3.8"
services:
  app:
    build:
      context: .
      dockerfile: Dockerfile.a
    ports:
      - "8080:8080"
    environment:
      DB_HOST: db
      DB_PORT: "5432"
      DB_NAME: student_grades
      DB_USER: student_app
      DB_PASSWORD: student_pass
      HTTP_PORT: "8080"
    depends_on:
      db:
        condition: service_healthy

  db:
    image: postgres:14.9
    environment:
      POSTGRES_DB: student_grades
      POSTGRES_USER: student_app
      POSTGRES_PASSWORD: student_pass
    volumes:
      - ./db:/docker-entrypoint-initdb.d
      - pgdata:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U student_app"]
      interval: 3s
      timeout: 5s
      retries: 5

volumes:
  pgdata:
```

- [ ] **Step 5: 创建 docker-compose.d.yml**

```yaml
version: "3.8"
services:
  app:
    build:
      context: .
      dockerfile: Dockerfile.d
    ports:
      - "8081:80"
    environment:
      DB_HOST: db
      DB_PORT: "5432"
      DB_NAME: student_grades
      DB_USER: student_app
      DB_PASSWORD: student_pass
    depends_on:
      db:
        condition: service_healthy

  db:
    image: postgres:14.9
    environment:
      POSTGRES_DB: student_grades
      POSTGRES_USER: student_app
      POSTGRES_PASSWORD: student_pass
    volumes:
      - ./db:/docker-entrypoint-initdb.d
      - pgdata:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U student_app"]
      interval: 3s
      timeout: 5s
      retries: 5

volumes:
  pgdata:
```

- [ ] **Step 6: 创建 docker-compose.test.yml**

```yaml
version: "3.8"
services:
  test:
    build:
      context: .
      dockerfile: Dockerfile.test
      args:
        COVERAGE: "${COVERAGE:-0}"
    environment:
      DB_HOST: test-db
      DB_PORT: "5432"
      DB_NAME: student_grades
      DB_USER: student_app
      DB_PASSWORD: student_pass
    depends_on:
      test-db:
        condition: service_healthy

  test-db:
    image: postgres:14.9
    environment:
      POSTGRES_DB: student_grades
      POSTGRES_USER: student_app
      POSTGRES_PASSWORD: student_pass
    volumes:
      - ./db:/docker-entrypoint-initdb.d
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U student_app"]
      interval: 3s
      timeout: 5s
      retries: 5
```

- [ ] **Step 7: 创建 nginx/default.conf**

```nginx
server {
    listen 80;
    server_name localhost;

    root /var/www/html;
    index index.php index.html;

    location / {
        fastcgi_pass   127.0.0.1:9000;
        include        fastcgi_params;
    }
}
```

- [ ] **Step 8: 创建 supervisord.conf**

```ini
[supervisord]
nodaemon=true
logfile=/var/log/supervisor/supervisord.log
pidfile=/var/run/supervisord.pid

[program:nginx]
command=/usr/sbin/nginx -g "daemon off;"
autostart=true
autorestart=true
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0

[program:fastcgi]
command=/usr/bin/spawn-fcgi -a 127.0.0.1 -p 9000 -n /app/build/app_d
autostart=true
autorestart=true
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0
```

---

### Task 12: 集成测试脚本

**Files:**
- Create: `test.sh`

- [ ] **Step 1: 创建 test.sh**

```bash
#!/bin/bash
# 学生成绩管理系统 — 集成测试脚本
# 用法: ./test.sh [A|D]  (默认 A 方案, 端口 8080; D 方案端口 8081)
# 前提: docker compose 已启动

set -euo pipefail

SCHEME="${1:-A}"
if [ "$SCHEME" = "D" ]; then
  PORT=8081
else
  PORT=8080
fi
BASE="http://localhost:${PORT}"

PASS=0
FAIL=0

check() {
  local desc="$1"
  local expected_code="$2"
  shift 2
  printf "  %s ... " "$desc"
  if "$@" > /dev/null 2>&1; then
    echo "✓ PASS"
    PASS=$((PASS + 1))
  else
    echo "✗ FAIL"
    FAIL=$((FAIL + 1))
  fi
}

echo "========================================="
echo " 集成测试 — 方案 ${SCHEME} (端口 ${PORT})"
echo "========================================="
echo ""

# TC-I01: 首页加载成功
check "HTTP 状态码 200" "" \
  bash -c "curl -s -o /dev/null -w '%{http_code}' '${BASE}/' | grep -q 200"

# TC-I02: 首页包含标题
check "页面标题" "" \
  bash -c "curl -s '${BASE}/' | grep -q '教育成绩数据分析平台'"

# TC-I03: 包含种子数据
check "种子数据 — 张三" "" \
  bash -c "curl -s '${BASE}/' | grep -q '张三'"

check "种子数据 — 李四" "" \
  bash -c "curl -s '${BASE}/' | grep -q '李四'"

# TC-I04: 班级筛选
check "班级筛选 — 一年一班包含张三" "" \
  bash -c "curl -s '${BASE}/?class=%E4%B8%80%E5%B9%B4%E4%B8%80%E7%8F%AD' | grep -q '张三'"

check "班级筛选 — 一年一班不含王五" "" \
  bash -c "! curl -s '${BASE}/?class=%E4%B8%80%E5%B9%B4%E4%B8%80%E7%8F%AD' | grep -q '王五'"

# TC-I05: 空结果处理
check "空结果显示暂无数据" "" \
  bash -c "curl -s '${BASE}/?class=不存在的班级' | grep -q '暂无成绩数据'"

# TC-I06: 表格结构
check "HTML 包含 <table>" "" \
  bash -c "curl -s '${BASE}/' | grep -q '<table>'"

check "下拉框包含全部班级选项" "" \
  bash -c "curl -s '${BASE}/' | grep -q '全部班级'"

echo ""
echo "========================================="
echo " 结果: ${PASS} 通过, ${FAIL} 失败"
echo "========================================="

[ "$FAIL" -eq 0 ] || exit 1
```

- [ ] **Step 2: 赋予执行权限**

```bash
chmod +x test.sh
```

---

## 实现顺序

```
Task 1  (脚手架)    →  Makefile + 目录结构
Task 2  (models)    →  数据结构
Task 3  (config)    →  配置读取 + test_config.cpp
Task 4  (dao)       →  数据库层
Task 5  (service)   →  业务层
Task 6  (template)  →  HTML 渲染
Task 7  (handler)   →  请求调度
Task 8  (main_a)    →  A 方案入口
Task 9  (main_d)    →  D 方案入口
Task 10 (测试)      →  test_service / test_dao / test_template
Task 11 (Docker)    →  Dockerfile ×3 + docker-compose ×3 + nginx + supervisor
Task 12 (集成测试)  →  test.sh
```

Task 1-7 为线性依赖，必须按序执行。Task 8/9 可在 Task 7 完成后并行。Task 10 依赖 Task 5/6。Task 11 和 12 在所有源码完成后执行。
