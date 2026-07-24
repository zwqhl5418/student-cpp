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
