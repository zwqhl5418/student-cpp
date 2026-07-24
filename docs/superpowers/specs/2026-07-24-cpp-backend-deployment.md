# 学生成绩管理系统 C++ 后端 — 容器化部署文档

> 版本：1.0 | 日期：2026-07-24

## 1. 部署架构

### 1.1 A 方案 — cpp-httplib 独立服务

```
┌─ Docker Compose ──────────────────────────────┐
│                                                │
│  ┌─ app 容器 (CentOS 7) ────────────────────┐  │
│  │  cpp-backend-a (cpp-httplib)              │  │
│  │  端口: 8080                               │  │
│  │  依赖: libpq, pthread                     │  │
│  └───────────────────────────────────────────┘  │
│              ↕ TCP :5432                        │
│  ┌─ db 容器 ─────────────────────────────────┐  │
│  │  postgres:14.9                             │  │
│  │  初始化: db/01-schema.sql, 02-seed.sql    │  │
│  └───────────────────────────────────────────┘  │
└────────────────────────────────────────────────┘
```

- 浏览器直接访问 `http://localhost:8080/`
- 不需要 Nginx

### 1.2 D 方案 — FastCGI + Nginx（与现有架构一致）

```
┌─ Docker Compose ──────────────────────────────┐
│                                                │
│  ┌─ app 容器 (CentOS 7) ────────────────────┐  │
│  │  supervisord                              │  │
│  │  ├─ nginx (:80)                           │  │
│  │  │   fastcgi_pass 127.0.0.1:9000          │  │
│  │  └─ spawn-fcgi → cpp-backend-d (:9000)    │  │
│  └───────────────────────────────────────────┘  │
│              ↕ TCP :5432                        │
│  ┌─ db 容器 ─────────────────────────────────┐  │
│  │  postgres:14.9                             │  │
│  └───────────────────────────────────────────┘  │
└────────────────────────────────────────────────┘
```

- 浏览器访问 `http://localhost:8081/`（与现有端口一致）
- 复用现有 Nginx 配置，仅替换 FastCGI 后端

---

## 2. 文件清单

### 2.1 A 方案新增文件

| 文件 | 说明 |
|------|------|
| `Dockerfile.a` | A 方案构建镜像 |
| `docker-compose.a.yml` | A 方案服务编排 |

### 2.2 D 方案新增文件

| 文件 | 说明 |
|------|------|
| `Dockerfile.d` | D 方案构建镜像（含 Nginx + supervisord） |
| `docker-compose.d.yml` | D 方案服务编排 |
| `nginx/default.conf` | Nginx FastCGI 配置（可能需微调） |
| `supervisord.conf` | 进程管理（nginx + spawn-fcgi） |

### 2.3 测试相关文件

| 文件 | 说明 |
|------|------|
| `Dockerfile.test` | 测试用镜像（含 gtest + lcov，从源码编译） |
| `docker-compose.test.yml` | 测试编排（test + test-db） |

### 2.4 构建脚本

| 文件 | 说明 |
|------|------|
| `Makefile` | 顶层 Makefile（`SCHEME=A|D` 切换，`test` 目标仅在 Docker 内使用） |
| `test.sh` | 集成测试（curl 驱动，需要先 `docker compose up`） |

---

## 3. Docker 配置

### 3.1 Dockerfile.a

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

WORKDIR /app
COPY . .

# 编译 A 方案
RUN make SCHEME=A -j$(nproc)

# 暴露端口
EXPOSE 8080

# 启动
CMD ["./build/app_a"]
```

### 3.2 Dockerfile.d

```dockerfile
FROM centos:7.9.2009

# 切换至 CentOS Vault 镜像源（官方镜像站已下线）
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

### 3.3 docker-compose.a.yml

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

### 3.4 docker-compose.d.yml

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

### 3.5 supervisord.conf（D 方案）

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

## 4. 常用命令

### 4.1 A 方案

```bash
# 启动
docker compose -f docker-compose.a.yml up -d --wait

# 访问
curl http://localhost:8080/

# 停止
docker compose -f docker-compose.a.yml down

# 重置数据
docker compose -f docker-compose.a.yml down -v
```

### 4.2 D 方案

```bash
# 启动
docker compose -f docker-compose.d.yml up -d --wait

# 访问
curl http://localhost:8081/

# 停止
docker compose -f docker-compose.d.yml down

# 重置数据
docker compose -f docker-compose.d.yml down -v
```

### 4.3 本地编译（编译产物在 Docker 中使用，本地仅做语法校验）

```bash
# 编译 A 方案（语法检查 + 生成二进制，在 Docker 中运行）
make SCHEME=A -j$(nproc)

# 编译 D 方案
make SCHEME=D -j$(nproc)

# 清理
make clean
```

> **注意**：`make` 仅做编译，不运行测试。所有测试必须在 Docker 隔离环境中执行，见下方 4.4 节。本地环境除 gcc-c++、make、libpq-devel 外无需安装其他依赖。

### 4.4 Docker 环境中运行测试

```bash
# 单元测试（一次性运行，结束后自动清理容器）
docker compose -f docker-compose.test.yml up --build --abort-on-container-exit

# 集成测试（先启动服务，再跑 curl）
docker compose -f docker-compose.a.yml up -d --wait
curl http://localhost:8080/
./test.sh
docker compose -f docker-compose.a.yml down

# 覆盖率测试
docker compose -f docker-compose.test.yml \
  --build-arg COVERAGE=1 \
  up --build --abort-on-container-exit
```

### 4.5 仅构建镜像（不运行）

```bash
# 构建 A 方案镜像
docker compose -f docker-compose.a.yml build

# 构建 D 方案镜像
docker compose -f docker-compose.d.yml build

# 构建测试镜像
docker compose -f docker-compose.test.yml build
```

---

## 5. Makefile 结构

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

.PHONY: all clean docker-test

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

### 5.1 test/Makefile 结构（仅在 Docker 容器内使用）

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

### 5.2 Dockerfile.test（测试用镜像）

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

# 安装 cpp-httplib（A 方案需要）
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

### 5.3 docker-compose.test.yml（测试编排）

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
