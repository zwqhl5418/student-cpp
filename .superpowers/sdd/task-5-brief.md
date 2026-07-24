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

