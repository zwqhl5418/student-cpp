# 学生成绩管理系统 C++ 后端 — 测试用例

> 版本：1.0 | 日期：2026-07-24

## 1. 测试策略

| 层级 | 框架 | 范围 |
|------|------|------|
| 单元测试 | Google Test | Service、DAO、Template 独立测试 |
| 集成测试 | shell 脚本 (curl) | 启动服务 → HTTP 请求 → 验证响应 |
| 对抗测试 | curl 对比 | A/D 方案输出一致性 |

---

## 2. 单元测试用例

### 2.1 Service 层 (`test/test_service.cpp`)

#### TC-S01: GetClasses — 获取所有不重复班级

```
前置条件: students 表有 一年一班、一年二班、一年三班
输入: 无
预期输出: ["一年一班", "一年二班", "一年三班"]（按班级名排序）
```

#### TC-S02: GetStudentScores — 无筛选条件（全部学生）

```
前置条件: 6 名学生，每人 4 科成绩
输入: classFilter = ""
预期输出: 6 个 PivotRow，每个包含 4 个科目
          按 class ASC, name ASC 排序
```

#### TC-S03: GetStudentScores — 按班级筛选

```
前置条件: 一年一班有 2 名学生
输入: classFilter = "一年一班"
预期输出: 2 个 PivotRow（张三、李四）
```

#### TC-S04: GetStudentScores — 筛选不存在的班级

```
前置条件: 不存在 "不存在的班级"
输入: classFilter = "不存在的班级"
预期输出: 0 个 PivotRow（空列表，非 NULL）
```

#### TC-S05: GetStudentScores — 学生无某科成绩

```
前置条件: 某学生在 scores 表缺少 "语文" 记录
输入: classFilter = (对应班级)
预期输出: 该学生的 scores map 中不包含 "语文"
          Template 层将其渲染为 "-"
```

### 2.2 DAO 层 (`test/test_dao.cpp`)

#### TC-D01: 数据库连接成功

```
前置条件: PostgreSQL 可访问，环境变量正确
输入: 调用 Connect()
预期输出: 连接句柄非空，状态码 CONNECTION_OK
```

#### TC-D02: 数据库连接失败 — 错误主机

```
前置条件: DB_HOST 设为不存在的地址
输入: 调用 Connect()
预期输出: 连接状态不为 CONNECTION_OK，返回错误信息
```

#### TC-D03: 参数化查询 — 防止 SQL 注入

```
前置条件: 数据库连接正常
输入: classFilter = "'; DROP TABLE students; --"
预期输出: 0 条结果（无匹配班级），表结构完好
```

### 2.3 Template 层 (`test/test_template.cpp`)

#### TC-T01: 正常数据渲染

```
前置条件: 传入 3 个 PivotRow（含各科成绩）
输入: classes = ["一年一班","一年二班"], rows = [...], selectedClass = ""
预期输出: HTML 字符串包含:
  - <title>教育成绩数据分析平台</title>
  - <select> 中有 <option value="">全部班级</option> 和两个班级选项
  - <table> 中有 3 行数据
```

#### TC-T02: 空数据渲染

```
前置条件: 无学生数据
输入: classes = ["一年一班"], rows = [], selectedClass = ""
预期输出: HTML 包含 "暂无成绩数据"，不包含 <table>
```

#### TC-T03: 筛选状态恢复

```
前置条件: 当前筛选 "一年一班"
输入: classes = [...], rows = [...], selectedClass = "一年一班"
预期输出: <option value="一年一班" selected>
```

### 2.4 Config 层 (`test/test_config.cpp`)

#### TC-C01: 环境变量读取

```
前置条件: 设置 DB_HOST=testhost, DB_PORT=5433
输入: LoadFromEnv()
预期输出: config.host == "testhost", config.port == 5433
```

#### TC-C02: 默认值回退

```
前置条件: 所有 DB_* 环境变量均未设置
输入: LoadFromEnv()
预期输出: 使用默认值: host="db", port=5432, dbName="student_grades" 等
```

---

## 3. 集成测试用例（curl 驱动）

### 3.1 与现有 test.sh 保持一致

```bash
# TC-I01: 首页加载成功
curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/
# 预期: 200

# TC-I02: 首页包含标题
curl -s http://localhost:8080/ | grep -q "教育成绩数据分析平台"
# 预期: 退出码 0

# TC-I03: 表格包含种子数据
curl -s http://localhost:8080/ | grep -q "张三"
# 预期: 退出码 0

# TC-I04: 班级筛选功能
curl -s "http://localhost:8080/?class=%E4%B8%80%E5%B9%B4%E4%B8%80%E7%8F%AD" \
  | grep -q "张三" && ! grep -q "王五"
# 预期: 退出码 0（含张三，不含王五）

# TC-I05: 空结果处理
curl -s "http://localhost:8080/?class=不存在的班级" | grep -q "暂无成绩数据"
# 预期: 退出码 0
```

### 3.2 A/D 方案一致性测试

```bash
# 启动 A 方案（端口 8081）
./build/app_a &
# 启动 D 方案（通过 Nginx 端口 8082）
# 对两个端点发相同请求，对比响应差异
diff <(curl -s "http://localhost:8081/" | sed 's/</\n</g' | grep -E '<(td|th|option)' | tr -d ' ')
     <(curl -s "http://localhost:8082/" | sed 's/</\n</g' | grep -E '<(td|th|option)' | tr -d ' ')
# 预期: 无差异（核心数据完全一致）
```

---

## 4. 测试覆盖率目标

| 模块 | 行覆盖率 | 分支覆盖率 |
|------|:------:|:------:|
| Service | ≥ 90% | ≥ 80% |
| DAO | ≥ 80% | ≥ 70% |
| Template | ≥ 85% | ≥ 75% |
| Config | 100% | 100% |
| 总体 | ≥ 85% | ≥ 75% |

---

## 5. 运行方式（全部在 Docker 隔离环境中执行）

### 5.1 单元测试

```bash
# 在 Docker 中编译并运行单元测试（不污染本地环境）
docker compose -f docker-compose.test.yml up --build --abort-on-container-exit
```

### 5.2 集成测试

```bash
# 启动服务（A 方案）
docker compose -f docker-compose.a.yml up -d --wait

# 运行集成测试（curl 驱动）
./test.sh

# 停止
docker compose -f docker-compose.a.yml down
```

### 5.3 带覆盖率

```bash
# 使用覆盖率构建的测试镜像
docker compose -f docker-compose.test.yml \
  --build-arg COVERAGE=1 \
  up --build --abort-on-container-exit
# lcov 报告生成在容器内，通过 volume 导出到本地 ./coverage/
```

> **注意**：所有编译和测试均在 Docker 容器内完成。本地环境不需要安装 gcc、gtest、libpq、lcov 等任何依赖。
