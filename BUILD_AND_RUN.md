# 学生成绩管理系统 C++ 后端 — 编译与运行指南

## 前置要求

本仓库是自包含的：vendored 依赖（cpp-httplib、FastCGI 头文件/库、libpq 头文件）已内置。你只需要：

| 工具 | 最低版本 | 用途 |
|------|:------:|------|
| g++ | 4.8.5+ | C++11 编译 |
| GNU Make | 3.81+ | 构建 |
| libpq5 | 任意 | PostgreSQL 运行时 (libpq.so.5) |

> **推荐：Docker**（见下方方式一）。所有依赖在容器内自动安装，零环境配置。

---

## 方式一：Docker Compose（推荐）

Docker Hub 需可达。镜像线上一键构建，无需手动安装任何编译工具。

### A 方案（cpp-httplib 独立 HTTP 服务）

```bash
# 启动（自动编译 + 启动 PostgreSQL + 运行服务）
docker compose -f docker-compose.a.yml up -d --wait

# 访问
curl http://localhost:8080/

# 停止
docker compose -f docker-compose.a.yml down

# 彻底重置（清数据库）
docker compose -f docker-compose.a.yml down -v
```

### D 方案（FastCGI + Nginx）

```bash
docker compose -f docker-compose.d.yml up -d --wait
curl http://localhost:8081/
docker compose -f docker-compose.d.yml down
```

### 运行测试

```bash
# 单元测试（一次性运行，自动退出）
docker compose -f docker-compose.test.yml up --build --abort-on-container-exit

# 带覆盖率
COVERAGE=1 docker compose -f docker-compose.test.yml up --build --abort-on-container-exit
```

---

## 方式二：本地编译

前提：系统已安装 `g++`、`make`、`libpq-dev`（提供 libpq-fe.h 和 libpq.so 链接）。

### 编译

```bash
# A 方案（默认）
make SCHEME=A -j$(nproc)

# D 方案
make SCHEME=D -j$(nproc)

# 如果 libpq 不在标准路径，手动指定:
make SCHEME=A CXXFLAGS="-std=c++11 -Wall -Wextra -O2 -I/usr/include/postgresql" LDFLAGS="-lpq -lpthread"
```

### 启动数据库

```bash
# 使用 Docker 启动 PostgreSQL（需要 Docker）
docker run -d --name pg \
  -e POSTGRES_DB=student_grades \
  -e POSTGRES_USER=student_app \
  -e POSTGRES_PASSWORD=student_pass \
  -v $(pwd)/db:/docker-entrypoint-initdb.d \
  -p 5432:5432 \
  postgres:14.9

# 等待就绪
until docker exec pg pg_isready -U student_app; do sleep 1; done
```

### 运行

```bash
# A 方案（直接监听 8080 端口）
DB_HOST=localhost DB_PORT=5432 DB_NAME=student_grades \
DB_USER=student_app DB_PASSWORD=student_pass \
HTTP_PORT=8080 ./build/app_a

# 验证
curl http://localhost:8080/
```

```bash
# D 方案（需要 nginx + spawn-fcgi）
# 安装: apt install nginx spawn-fcgi  (Debian/Ubuntu)
#       yum install nginx spawn-fcgi  (CentOS)

# 复制 nginx 配置
sudo cp nginx/default.conf /etc/nginx/conf.d/default.conf
sudo nginx -s reload

# 启动 FastCGI 后端
DB_HOST=localhost DB_PORT=5432 DB_NAME=student_grades \
DB_USER=student_app DB_PASSWORD=student_pass \
spawn-fcgi -a 127.0.0.1 -p 9000 -n ./build/app_d

# 验证（nginx 默认监听 80 端口）
curl http://localhost/
```

### 集成测试

```bash
# 先确保服务已启动
./test.sh A   # 测试 A 方案（端口 8080）
./test.sh D   # 测试 D 方案（端口 8081）
```

---

## 项目结构速览

```
src/          13 个 .cpp/.h 文件（~950 行 C++11 代码）
  ├── models.h         数据结构
  ├── config.h/cpp     配置（环境变量读取）
  ├── dao.h/cpp        数据访问层（libpq 参数化 SQL）
  ├── service.h/cpp    业务逻辑层
  ├── template.h/cpp   HTML 渲染（深色科幻主题）
  ├── handler.h/cpp    请求调度
  ├── main_a.cpp       A 方案入口（cpp-httplib）
  └── main_d.cpp       D 方案入口（FastCGI）

test/         4 个测试文件（13 个测试用例）
  ├── test_config.cpp
  ├── test_dao.cpp
  ├── test_service.cpp
  └── test_template.cpp

include/      vendored 头文件（httplib.h, libpq-fe.h, fcgio.h）
lib/          vendored 库文件（libpq.so, libfcgi.so）

db/           数据库初始化脚本（建表 + 种子数据）

Makefile      顶层构建
Dockerfile.*  3 个 Docker 镜像定义
docker-compose.*.yml  3 个服务编排
nginx/        D 方案 nginx 配置
test.sh       集成测试脚本

docs/         设计文档（概要设计/接口/测试/部署/实现计划）
```

## 环境变量

| 变量 | 默认值 | 说明 |
|------|--------|------|
| DB_HOST | db | PostgreSQL 主机 |
| DB_PORT | 5432 | PostgreSQL 端口 |
| DB_NAME | student_grades | 数据库名 |
| DB_USER | student_app | 数据库用户 |
| DB_PASSWORD | student_pass | 数据库密码 |
| HTTP_PORT | 8080 | 监听端口（仅 A 方案） |
