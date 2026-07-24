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

