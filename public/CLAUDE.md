# CLAUDE.md

本文件为 Claude Code（claude.ai/code）在此仓库中工作时提供指引。

## 项目概述

教育成绩数据分析平台 — 一个单页 PHP 应用，以数据透视表形式展示学生成绩，支持按班级筛选。

**技术栈：** PHP 8.2 (php-fpm) + PostgreSQL 14.9 + Nginx，通过 Docker Compose 容器化部署，supervisord 管理进程。

## 常用命令

```bash
# 启动所有服务（app + db，等待 PostgreSQL 健康检查通过）
docker compose up -d --wait

# 停止并删除容器
docker compose down

# 停止容器并删除数据库卷（彻底重置，下次启动重跑建表和种子数据）
docker compose down -v

# 运行集成测试（启动服务 → curl 测试 → 自动清理）
./test.sh
```

应用访问地址：`http://localhost:8081/`（端口说明见下方注意事项）。

## 架构

```
浏览器 (port 8081)
  → Nginx (容器内 80 端口，将 .php 请求路由到 php-fpm)
    → public/index.php（唯一入口文件）
      → PostgreSQL (host: db, port: 5432, database: student_grades)
```

### 请求处理流程

1. Nginx 接收所有请求（`try_files $uri /index.php?$query_string`）
2. `.php` 请求通过 FastCGI 转发到 `127.0.0.1:9000`（php-fpm）
3. `public/index.php` 从环境变量读取数据库连接信息（由 docker-compose 注入）
4. 查询 `students` 表中所有不重复的班级，用于筛选下拉框
5. 使用 `MAX(CASE WHEN subject = 'X' THEN score END)` 构建动态透视查询，每个学生一行，科目作为列
6. 渲染 HTML 页面（表格 + 班级筛选下拉框，下拉框变更时自动提交表单）

### 数据库表结构（`db/01-schema.sql`）

| 表名 | 字段 | 说明 |
|------|------|------|
| `students` | id (SERIAL PK), name (VARCHAR 100), class (VARCHAR 50), created_at | 学生表 |
| `scores` | id (SERIAL PK), student_id (FK→students, CASCADE DELETE), subject (VARCHAR 50), score (NUMERIC 5,2), created_at | 成绩表 |

两个 SQL 文件挂载到容器的 `/docker-entrypoint-initdb.d/`，PostgreSQL 首次启动时自动执行。

### 种子数据（`db/02-seed.sql`）

- 3 个班级（一年一班/一年二班/一年三班），每班 2 名学生，共 6 人
- 每人 4 科成绩（语文/数学/英语/科学），共 24 条记录

### 容器架构

```
┌─ app 容器 ────────────────────────────────────────┐
│  supervisord                                        │
│  ├─ nginx (80 端口，前台运行)                        │
│  │   提供静态文件 + 将 .php 请求代理到 php-fpm       │
│  └─ php-fpm (9000 端口，前台运行)                    │
│                                                      │
│  挂载点：                                            │
│  - ./public → /var/www/html（应用代码）              │
│  - ./nginx/default.conf → /etc/nginx/conf.d/        │
└──────────────────────────────────────────────────────┘
          ↕ PostgreSQL TCP (5433 端口)
┌─ db 容器 ─────────────────────────────────────────┐
│  postgres:14.9                                      │
│                                                      │
│  挂载点：                                            │
│  - ./db → /docker-entrypoint-initdb.d/（初始化脚本）│
│  - pgdata 卷 → /var/lib/postgresql/data             │
│  健康检查：pg_isready -U student_app                 │
└──────────────────────────────────────────────────────┘
```

## 核心代码模式

### 应用常量驱动

`public/index.php` 第 14 行的 `$subjects` 数组是科目列的唯一数据源：

```php
$subjects = ['语文', '数学', '英语', '科学'];
```

该数组同时驱动 SQL 透视查询的构建和 HTML 表格表头/表体的渲染。新增科目只需向该数组添加一项——透视查询和表格渲染会自动适配。

### 安全的动态 SQL

透视查询中的科目名称通过 `$pdo->quote()` 转义（这些值是应用常量，非用户输入，无注入风险）。班级筛选使用预编译语句参数（`:class`）。

### 样式内联在 index.php 中

没有独立的 CSS 文件——所有样式（约 150 行）写在 `index.php` 的 `<style>` 块内。设计风格为深色科幻主题，包含动画渐变光球、网格背景和旋转线框地球仪。

### 错误处理

- `pdo_pgsql` 扩展未安装 → HTTP 500 + 中文错误页面
- PDO 连接失败 → HTTP 500 + 中文错误页面
- 查询结果为空 → 显示"暂无成绩数据"提示，不渲染空表格
- 成绩格式化：`formatScore()` 去掉尾部 `.00`，将 `null` 显示为 `-`

## 注意事项

### 端口问题：8081 vs 8080

当前 docker-compose 映射的是 `8081:80`。集成测试脚本 `test.sh` 硬编码使用 8080 端口。如果测试报连接拒绝，任选其一：
- 将 `docker-compose.yml` 中的端口改回 `"8080:80"`
- 将 `test.sh` 中的端口改为 8081

### 数据库持久化

`pgdata` 卷会在 `docker compose down` 后保留数据。如需彻底重置数据库，使用 `docker compose down -v`（会删除数据卷，下次 `up` 时重新执行初始化脚本）。

### 种子数据仅在首次启动时加载

种子数据只在数据库卷为空时执行。修改 `db/*.sql` 文件后，需要先 `docker compose down -v` 再 `docker compose up -d --wait` 才能生效。

### PHP 文件即时生效

`./public` 目录以卷挂载方式挂载到容器内，修改 PHP 文件后无需重新构建镜像即可立即生效。

## 项目文件地图

| 路径 | 职责 |
|------|------|
| `public/index.php` | 唯一入口——全部应用逻辑 + HTML 渲染 |
| `db/01-schema.sql` | 数据库表结构（students + scores） |
| `db/02-seed.sql` | 种子数据（6 名学生 × 4 个科目） |
| `nginx/default.conf` | Nginx 配置——所有请求路由到 index.php |
| `docker-compose.yml` | 服务编排（app + db + pgdata 卷） |
| `Dockerfile` | PHP 8.2 镜像 + nginx + supervisor + pdo_pgsql |
| `supervisord.conf` | 进程管理配置（nginx + php-fpm） |
| `test.sh` | 集成测试（curl 驱动，5 个测试用例） |
| `openspec/specs/` | 正式规格基线 |
| `openspec/changes/archive/` | 已归档的变更记录 |

## 开发工作流

本项目使用 OpenSpec 进行规格驱动开发（`openspec/` 目录），使用 Comet 管理工作流（`.comet/` 目录，语言：zh-CN）。

Comet 环境恢复已配置——开始工作时，请先检查是否存在活跃的 Comet 工作流。详见 `AGENTS.md` 中的恢复探测说明。
