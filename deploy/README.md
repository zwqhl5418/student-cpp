# 学生成绩管理系统 — 私网离线部署指南

> 方案 A：cpp-httplib 独立 HTTP 服务  
> 目标环境：CentOS 7.6 ×86_64  
> 技术栈：纯 C++11，零容器依赖

---

## 1. 架构概览

```
                    TCP :5432
  [app_a :8080] ──────────────► [PostgreSQL]
  cpp-httplib                   学生成绩库
  独立 HTTP 服务

  依赖链：app_a → libpq.so.5 → glibc 2.17（CentOS 7.6 原生）
```

- **app_a**：单文件静态链接 HTTP 服务二进制（~500KB），监听 HTTP 端口
- **libpq.so.5**：PostgreSQL 客户端库，vendored 在 `lib/` 目录
- 无 Nginx、无 FastCGI、无 supervisor、无 Docker

---

## 2. 部署包目录结构

```
deploy/
├── app_a                # 预编译二进制（需在 CentOS 7.6 上编译）
├── start.sh             # 启动脚本
├── stop.sh              # 停止脚本
├── lib/                 # 运行时库
│   ├── libpq.so.5.16    # PostgreSQL 客户端（实体文件）
│   ├── libpq.so.5 -> libpq.so.5.16
│   └── libpq.so -> libpq.so.5
├── db/                  # 数据库初始化
│   ├── 01-schema.sql    # 建表语句
│   └── 02-seed.sql      # 种子数据（6 名学生 + 24 条成绩）
├── opt/                 # 可选组件
│   ├── pgdg-redhat-repo-latest.noarch.rpm  # PG yum 仓库
│   ├── download-pg-rpms.sh                 # PG RPM 下载脚本
│   └── pg_rpms/                            # 离线 PG RPM 包（下载后）
└── README.md            # 本文档
```

---

## 3. 环境变量参考

| 变量 | 默认值 | 说明 |
|------|:------:|------|
| `DB_HOST` | `localhost` | PostgreSQL 主机地址 |
| `DB_PORT` | `5432` | PostgreSQL 端口 |
| `DB_NAME` | `student_grades` | 应用数据库名（start.sh 自动创建） |
| `DB_USER` | `student_app` | 应用数据库用户（start.sh 自动创建） |
| `DB_PASSWORD` | `student_pass` | 应用数据库密码 |
| `DB_ADMIN_USER` | `postgres` | PG 管理员用户（建库建用户用） |
| `DB_ADMIN_PASSWORD` | 无 | PG 管理员密码（**仅首次需要**，不设则跳过建库） |
| `HTTP_PORT` | `8080` | app_a 监听端口 |
| `PSQL_CMD` | `psql` | psql 命令（可设为 `docker exec pg psql`） |
| `SKIP_DB_SETUP` | `0` | 设为 `1` 跳过自动建库建用户 |
| `SKIP_DB_INIT` | `0` | 设为 `1` 跳过自动建表 |
| `FORCE_REINIT` | `0` | 设为 `1` 强制重建全部 |

---

## 4. 部署场景

### 场景 A：连接已有 PostgreSQL（最简，~500KB）

**前提**：已有 PostgreSQL 实例，且数据库和用户已创建。

**准备 PG（Docker 方式 — 最简）：**

```bash
docker run -d \
  --name pg \
  -e POSTGRES_PASSWORD=postpass \
  -e POSTGRES_INITDB_ARGS='--auth-host=md5 --auth-local=trust' \
  9ace7db0a394 \
  postgres -c listen_addresses='*'
```

> 只需设 `POSTGRES_PASSWORD`（管理员密码）。数据库和用户由 start.sh 自动创建。

**准备 PG（已有实例）：**

```sql
CREATE USER student_app WITH PASSWORD 'student_pass';
CREATE DATABASE student_grades OWNER student_app;
```

**步骤：**

```bash
# 1. 拷贝部署包到目标机器
scp -r deploy/ user@target:/opt/student-grades/
cd /opt/student-grades

# 2. 启动（首次运行会自动建库建用户建表）:
export DB_HOST=192.168.1.100          # PG 地址
export DB_ADMIN_PASSWORD=postpass     # PG 管理员密码（仅首次需要）
./start.sh

# 再次启动无需 DB_ADMIN_PASSWORD:
export DB_HOST=192.168.1.100
./start.sh

# 3. 验证
curl http://localhost:8080/

# 4. 停止
./stop.sh
```

start.sh 会自动等待 PG 就绪，并首次初始化 schema 和种子数据。

### 场景 B：自带 PostgreSQL（完整离线，~80MB）

**前提**：目标机器是全新 CentOS 7.6，数据库和 app 都从零开始。

#### B-1: 准备 PG RPM 包（在联网机器上）

```bash
# 在一台能访问外网的 CentOS 7.6 机器上:
cd deploy/opt/
./download-pg-rpms.sh
# 输出: pg_rpms/ 目录，约 20-40MB
```

#### B-2: 离线安装 PostgreSQL

```bash
# 将 deploy/ 整体拷贝到私网机器
cd /opt/student-grades/opt

# 安装 RPM
sudo rpm -ivh pgdg-redhat-repo-latest.noarch.rpm 2>/dev/null || true
sudo rpm -ivh pg_rpms/*.rpm

# 初始化数据库
sudo /usr/pgsql-14/bin/postgresql-14-setup initdb

# 配置监听地址（如需要远程连接）
sudo sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" \
    /var/lib/pgsql/14/data/postgresql.conf

# 配置认证（如需要密码登录）
echo "host  all  all  0.0.0.0/0  md5" | \
    sudo tee -a /var/lib/pgsql/14/data/pg_hba.conf

# 启动
sudo systemctl enable postgresql-14
sudo systemctl start postgresql-14

# 创建数据库和用户
sudo -u postgres /usr/pgsql-14/bin/createuser student_app -P
# 输入密码: student_pass
sudo -u postgres /usr/pgsql-14/bin/createdb student_grades -O student_app
```

#### B-3: 启动应用

```bash
cd /opt/student-grades
export DB_HOST=localhost
export DB_PORT=5432
export DB_NAME=student_grades
export DB_USER=student_app
export DB_PASSWORD=student_pass

./start.sh
curl http://localhost:8080/
```

---

## 5. 编译指南（两种方式）

### 方式一：在私网机器上直接编译（推荐）

整个编译链自包含 —— 只要机器上有 `g++` 和 `make`，无需联网。

#### 5.1 前提：替换 libpq.so 为当前平台版本

> ⚠️ **重要**：仓库 `lib/` 中的 `libpq.so.5.16` 是占位文件（Debian 版本），
> 必须在当前平台上替换为本地版本后再编译。

```bash
# 如果目标机器已安装 postgresql-libs:
cp /usr/lib64/libpq.so.5   lib/libpq.so.5.16
# 或者静态链接（如果装了 postgresql-devel）:
# 直接用: make SCHEME=A PQ_FROM=system

# 如果目标机器没有 PG 包，从同版本 CentOS 7.6 机器获取:
scp centos76:/usr/lib64/libpq.so.5 lib/libpq.so.5.16
```

#### 5.2 自检 + 编译

```bash
cd /opt/student-grades   # 或任意部署路径

# 第一步：自检（确认环境完整）
make check-offline
# 期望输出: 全部 [OK]

# 第二步：编译（一键）
make SCHEME=A -j$(nproc)
# 或等效的:
make build-offline -j$(nproc)

# 第三步：验证
file build/app_a
# 期望: ELF 64-bit LSB executable, x86-64, ... for GNU/Linux 2.6.32

# 第四步：安装到 deploy/
cp build/app_a deploy/
```

#### 5.3 系统 libpq 编译（备选）

如果目标机器已通过离线 RPM 安装了完整的 `postgresql-devel`：

```bash
make SCHEME=A PQ_FROM=system -j$(nproc)
```

此模式链接系统 `/usr/lib64/libpq.so`，不需要 vendored 库。

### 方式二：在联网机器上预编译（交叉部署）

在一台有网的 CentOS 7.6 上编译好，拷贝二进制到私网机器（参见第一节架构）。

```bash
make SCHEME=A -j$(nproc)
cp build/app_a deploy/
# 将 deploy/ 打包拷贝到私网机器
```

### 编译依赖速查

| 依赖 | 来源 | 安装方式（离线） |
|------|------|------|
| gcc-c++ (g++ 4.8.5) | CentOS 7.6 ISO/DVD | `yum --disablerepo=\* --enablerepo=c7-media install gcc-c++` |
| GNU Make 3.81+ | CentOS 7.6 默认安装 | 通常已预装 |
| libpq 头文件 | 仓库 `include/libpq*.h` | **已 vendored，无需安装** |
| cpp-httplib | 仓库 `include/httplib.h` | **已 vendored，无需安装** |
| libpq.so (链接+运行时) | 仓库 `lib/libpq.so*` | 需替换为当前平台版本（见 5.1） |

### PQ_FROM 变量说明

`make SCHEME=A PQ_FROM=vendor` 和 `make SCHEME=A` 完全等价 ——
默认就是 vendored 模式，零外部依赖。

---

## 6. 验证清单

```bash
# HTTP 状态码 200
curl -s -o /dev/null -w '%{http_code}' http://localhost:8080/

# 页面包含标题
curl -s http://localhost:8080/ | grep -q '教育成绩数据分析平台'

# 包含种子数据
curl -s http://localhost:8080/ | grep -q '张三'

# 班级筛选功能
curl -s 'http://localhost:8080/?class=%E4%B8%80%E5%B9%B4%E4%B8%80%E7%8F%AD' | grep -q '张三'
curl -s 'http://localhost:8080/?class=%E4%B8%80%E5%B9%B4%E4%B8%80%E7%8F%AD' | grep -q '王五' && echo "FAIL" || echo "PASS"

# 空结果
curl -s 'http://localhost:8080/?class=不存在' | grep -q '暂无成绩数据'
```

---

## 7. 故障排查

| 症状 | 可能原因 | 解决 |
|------|----------|------|
| `./app_a: /lib64/libc.so.6: version GLIBC_2.18 not found` | 二进制在 glibc 较新的系统上编译 | 在 CentOS 7.6 上重新编译 |
| `./app_a: /lib64/libstdc++.so.6: version CXXABI_1.3.8 not found` | 用了 devtoolset 编译但未打包 libstdc++ | 静态链接 libstdc++：`-static-libstdc++` |
| `could not connect to server` | PG 未启动或地址错误 | 检查 `DB_HOST`、`DB_PORT`，确认防火墙放行 |
| `FATAL: password authentication failed` | 密码错误 | 检查 `DB_PASSWORD`，在 PG 端重置：`ALTER USER student_app PASSWORD 'xxx';` |
| `relation "students" does not exist` | DB 未初始化 | 手动执行 `db/01-schema.sql` 和 `db/02-seed.sql` |
| 端口 8080 被占用 | 有其他服务监听 8080 | 设置 `HTTP_PORT=9090` 或其他端口 |
| `libpq.so.5: cannot open shared object file` | LD_LIBRARY_PATH 未设置 | start.sh 自动设置，手动运行时执行 `export LD_LIBRARY_PATH=./lib:$LD_LIBRARY_PATH` |
| `SCRAM authentication requires libpq version 10 or above` | PG14 默认 SCRAM，旧 psql 不支持 | 重建容器加 `POSTGRES_INITDB_ARGS='--auth-host=md5 --auth-local=trust'`（见场景 A Docker 命令） |

---

## 8. 安全加固建议（私网环境）

- **防火墙**：限制 8080 端口仅允许内网 IP 段访问
  ```bash
  sudo iptables -A INPUT -p tcp --dport 8080 -s 192.168.0.0/16 -j ACCEPT
  sudo iptables -A INPUT -p tcp --dport 8080 -j DROP
  ```
- **PostgreSQL**：使用 `pg_hba.conf` 限制连接来源
- **系统用户**：以非 root 用户运行 app_a
  ```bash
  useradd -r -s /sbin/nologin studentapp
  chown -R studentapp:studentapp /opt/student-grades
  sudo -u studentapp ./start.sh
  ```
- **只读文件**：app_a 不需要写权限（除 PID 文件和日志）
