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

