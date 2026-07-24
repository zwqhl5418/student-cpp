### Task 11: Docker 容器化部署

**Files:**
- Create: `Dockerfile.a`
- Create: `Dockerfile.d`
- Create: `Dockerfile.test`
- Create: `docker-compose.a.yml`
- Create: `docker-compose.d.yml`
- Create: `docker-compose.test.yml`
- Create: `nginx/default.conf`
- Create: `supervisord.conf`

- [ ] **Step 1: 创建 Dockerfile.a**

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

# 下载 cpp-httplib
RUN curl -fsSL -o /usr/local/include/httplib.h \
    https://raw.githubusercontent.com/yhirose/cpp-httplib/v0.23.0/httplib.h

WORKDIR /app
COPY . .

# 编译 A 方案
RUN make SCHEME=A -j$(nproc)

EXPOSE 8080

CMD ["./build/app_a"]
```

- [ ] **Step 2: 创建 Dockerfile.d**

```dockerfile
FROM centos:7.9.2009

# 切换至 CentOS Vault 镜像源
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

- [ ] **Step 3: 创建 Dockerfile.test**

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

# 下载 cpp-httplib（A 方案编译需要）
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

- [ ] **Step 4: 创建 docker-compose.a.yml**

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

- [ ] **Step 5: 创建 docker-compose.d.yml**

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

- [ ] **Step 6: 创建 docker-compose.test.yml**

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

- [ ] **Step 7: 创建 nginx/default.conf**

```nginx
server {
    listen 80;
    server_name localhost;

    root /var/www/html;
    index index.php index.html;

    location / {
        fastcgi_pass   127.0.0.1:9000;
        include        fastcgi_params;
    }
}
```

- [ ] **Step 8: 创建 supervisord.conf**

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

