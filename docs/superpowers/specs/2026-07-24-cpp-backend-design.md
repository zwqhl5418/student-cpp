# 学生成绩管理系统 C++ 后端 — 概要设计文档

> 版本：1.0 | 日期：2026-07-24 | 作者：Claude

## 1. 概述

### 1.1 项目背景

现有「教育成绩数据分析平台」使用 PHP 8.2 + Nginx + PostgreSQL，以单体 `index.php` 渲染成绩透视表页面。本项目使用 C++11 重写后端服务，保持功能完全等价，同时提供两套可选的 HTTP 接入方案（cpp-httplib / FastCGI+Nginx）。

### 1.2 设计目标

| 目标 | 说明 |
|------|------|
| 功能等价 | 完全复刻现有 PHP 版行为：班级下拉筛选 + 成绩透视表 + 深色科幻主题 |
| 双方案并行 | A 方案（cpp-httplib 独立服务）和 D 方案（FastCGI + Nginx）共享全部业务代码，仅入口不同 |
| C++11 兼容 | 所有代码使用 C++11 及以下特性，gcc 4.8.5 (CentOS 7.4) 可编译 |
| Google 规范 | 遵循 Google C++ Style Guide，驼峰命名，中文注释 |
| 零外部依赖 | 除 libpq 外不引入第三方 C++ 库（cpp-httplib 为单头文件 vendored） |

### 1.3 术语定义

| 术语 | 含义 |
|------|------|
| A 方案 | 使用 cpp-httplib 单头文件库，独立监听 HTTP 端口 |
| D 方案 | 使用 libfcgi 库，通过 FastCGI 协议与 Nginx 通信 |
| 透视查询 | 将 `scores` 表行转列，每个学生一行、每科一列 |
| 共享层 | Handler/Service/DAO/Template 四个模块，A/D 方案共用 |

---

## 2. 系统架构

### 2.1 分层架构图

```
┌──────────────────────────────────────────────────────┐
│                   入口层（不共享）                     │
│  ┌──────────────────┐  ┌──────────────────────────┐  │
│  │ main_a.cpp       │  │ main_d.cpp               │  │
│  │ cpp-httplib::Svr │  │ FCGX_Accept_r 循环       │  │
│  │ 监听 :8080       │  │ FastCGI (spawn-fcgi)     │  │
│  └────────┬─────────┘  └───────────┬──────────────┘  │
│           │                        │                  │
│           └──────────┬─────────────┘                  │
│                      │ 调用                          │
├──────────────────────▼───────────────────────────────┤
│                  Handler 处理器层                      │
│  handler.cpp/h                                        │
│  - HandleIndex(): 解析 GET 参数 (class)               │
│  - 调用 Service 获取数据                              │
│  - 调用 Template 渲染 HTML                            │
├──────────────────────┬───────────────────────────────┤
│                  Service 业务层                        │
│  service.cpp/h                                        │
│  - GetClasses(): 获取班级列表                         │
│  - GetStudentScores(class): 获取成绩透视数据          │
├──────────────────────┬───────────────────────────────┤
│                   DAO 数据访问层                       │
│  dao.cpp/h                                            │
│  - 基于 libpq (C API) 直连 PostgreSQL                 │
│  - ExecuteQuery(sql, params): 执行参数化查询          │
│  - 单连接管理（连接复用 + 异常断开自动重连）          │
├──────────────────────┬───────────────────────────────┤
│                      │                                │
│            config    models    template               │
│            .cpp/h    .h        .cpp/h                 │
└──────────────────────┴───────────────────────────────┘
```

### 2.2 模块职责

| 模块 | 文件 | 职责 | 依赖 |
|------|------|------|------|
| **入口A** | `src/main_a.cpp` | 初始化 httplib::Server，注册路由，启动监听 | cpp-httplib, handler |
| **入口D** | `src/main_d.cpp` | 初始化 FCGX，Accept 循环，调用 handler | libfcgi++, handler |
| **Handler** | `src/handler.cpp/h` | 解析 HTTP 请求参数，调度 Service，返回 HTML 字符串 | service, template |
| **Service** | `src/service.cpp/h` | 业务逻辑：班级列表查询、成绩透视查询、数据组装 | dao, models |
| **DAO** | `src/dao.cpp/h` | 数据库连接管理、SQL 执行、结果集映射 | libpq, models |
| **Template** | `src/template.cpp/h` | 渲染 HTML 页面（完全复刻现有深色科幻主题样式） | models |
| **Models** | `src/models.h` | 数据结构定义：Student, Score, PivotRow | 无 |
| **Config** | `src/config.cpp/h` | 从环境变量读取数据库连接信息 | 无 |

### 2.3 关键数据结构

```cpp
// 学生基本信息
struct Student {
  int id;
  std::string name;
  std::string className;
};

// 成绩透视行（一个学生 + 各科成绩）
struct PivotRow {
  int studentId;
  std::string studentName;
  std::string className;
  std::map<std::string, double> scores;  // 科目 → 分数
};

// 数据库连接配置
struct DbConfig {
  std::string host;
  int port;
  std::string dbName;
  std::string user;
  std::string password;
};
```

---

## 3. 核心流程

### 3.1 请求处理时序

```
浏览器                   入口(main)            Handler           Service            DAO              PostgreSQL
  │                         │                    │                 │                 │                  │
  │ GET /?class=一年一班    │                    │                 │                 │                  │
  │────────────────────────>│                    │                 │                 │                  │
  │                         │ HandleIndex(req)   │                 │                 │                  │
  │                         │───────────────────>│                 │                 │                  │
  │                         │                    │ GetClasses()    │                 │                  │
  │                         │                    │────────────────>│                 │                  │
  │                         │                    │                 │ QueryClasses()  │                  │
  │                         │                    │                 │────────────────>│                  │
  │                         │                    │                 │                 │ SELECT DISTINCT  │
  │                         │                    │                 │                 │ class FROM students
  │                         │                    │                 │                 │─────────────────>│
  │                         │                    │                 │                 │<─── 结果集 ─────│
  │                         │                    │                 │<────────────────│                  │
  │                         │                    │ GetStudentScores│                 │                  │
  │                         │                    │ ("一年一班")    │                 │                  │
  │                         │                    │────────────────>│                 │                  │
  │                         │                    │                 │ QueryPivot()    │                  │
  │                         │                    │                 │────────────────>│                  │
  │                         │                    │                 │                 │ 透视查询          │
  │                         │                    │                 │                 │─────────────────>│
  │                         │                    │                 │                 │<─── 结果集 ─────│
  │                         │                    │                 │<────────────────│                  │
  │                         │                    │<── PivotRows ───│                 │                  │
  │                         │                    │                 │                 │                  │
  │                         │                    │ RenderPage()    │                 │                  │
  │                         │                    │──────────────────────────────────────────────────────│
  │                         │                    │<── HTML 字符串 ──────────────────────────────────────│
  │                         │<── HTML 字符串 ────│                 │                 │                  │
  │<── HTTP 200 text/html ──│                    │                 │                 │                  │
```

### 3.2 SQL 透视查询

```sql
SELECT s.id, s.name, s.class,
  MAX(CASE WHEN sc.subject = '语文' THEN sc.score END) AS "语文",
  MAX(CASE WHEN sc.subject = '数学' THEN sc.score END) AS "数学",
  MAX(CASE WHEN sc.subject = '英语' THEN sc.score END) AS "英语",
  MAX(CASE WHEN sc.subject = '科学' THEN sc.score END) AS "科学"
FROM students s
LEFT JOIN scores sc ON s.id = sc.student_id
WHERE s.class = $1              -- 参数化，仅当 class 非空时附加
GROUP BY s.id, s.name, s.class
ORDER BY s.class, s.name;
```

---

## 4. 方案差异对比

| 维度 | A 方案 (cpp-httplib) | D 方案 (FastCGI+Nginx) |
|------|----------------------|------------------------|
| 入口文件 | `main_a.cpp` (~30行) | `main_d.cpp` (~50行) |
| 进程模型 | 内置多线程 | spawn-fcgi 管理多进程 |
| 前端代理 | 不需要 Nginx | 必须 Nginx |
| Docker 镜像 | 单阶段，仅 C++ 程序 | 需 Nginx + spawn-fcgi |
| 编译依赖 | libpq + pthread | libpq + libfcgi++ + pthread |
| 配置复杂度 | 低（仅端口号） | 中（Nginx 配置 + FastCGI 参数） |

---

## 5. 错误处理策略

| 错误场景 | HTTP 状态码 | 行为 |
|----------|:----------:|------|
| DB 连接失败 | 500 | 返回错误页面 "数据库连接失败，请检查配置" |
| SQL 执行失败 | 500 | 返回错误页面，详细错误写入 stderr |
| 查询结果为空 | 200 | 返回正常页面，表格区域显示 "暂无成绩数据" |
| 非法请求参数 | 200 | 忽略非法参数，按无筛选处理（不报错） |
| 科目无成绩 (NULL) | 200 | 显示 "-" |

---

## 6. 技术选型说明

| 技术 | 选型 | 理由 |
|------|------|------|
| HTTP (A方案) | cpp-httplib v0.23+ | header-only、C++11、16.7k GitHub stars，vendored 到 `include/httplib.h` |
| HTTP (D方案) | libfcgi 2.4.0 | CentOS 7 yum 安装、29 年验证、与现有 Nginx 架构兼容 |
| 数据库 | libpq (PostgreSQL C API) | 零额外依赖、PostgreSQL 原生驱动、C++ 可直接调用 |
| 构建 | GNU Make | 系统自带，CentOS 7 无需额外安装 |
| 测试 | Google Test | 与 CLAUDE.md 约定一致 |
| 容器化 | Docker (CentOS 7 基础镜像) | 可选项：Alpine 更小但需 musl 兼容；CentOS 7 保证二进制兼容 |
