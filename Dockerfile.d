FROM docker.m.daocloud.io/library/centos:7.6.1810

# 切换至 CentOS Vault 归档镜像源
RUN sed -i 's/mirrorlist/#mirrorlist/g' /etc/yum.repos.d/CentOS-*.repo && \
    sed -i 's|#baseurl=http://mirror.centos.org|baseurl=http://vault.centos.org|g' /etc/yum.repos.d/CentOS-*.repo

# CentOS 基础源有 gcc-c++, make, postgresql-devel
# EPEL 归档源有 fcgi-devel, spawn-fcgi, nginx, supervisor
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

# D 方案 — 使用系统 yum 安装的 libfcgi，移除 vendored 版本（ABI 不兼容）
RUN rm -f lib/libfcgi.so lib/libfcgi++.so lib/libfcgi.so.0 lib/libfcgi++.so.0 lib/libfcgi.so.0.0.0 lib/libfcgi++.so.0.0.0 lib/libfcgi.a lib/libfcgi++.a
RUN make SCHEME=D CXXFLAGS="-std=c++11 -Wall -Wextra -O2 -Iinclude -DBUILD_SCHEME_D" \
    LDFLAGS="-lpq -lpthread -lfcgi -lfcgi++" -j$(nproc)

# 移除 nginx 默认 server 块（会抢 port 80）
RUN rm -f /etc/nginx/conf.d/default.conf && \
    sed -i '/^    server {/,/^    }/s/^    /    #/' /etc/nginx/nginx.conf
COPY nginx/default.conf /etc/nginx/conf.d/default.conf
COPY supervisord.conf /etc/supervisord.conf

EXPOSE 80

# 启动脚本：将 Docker 环境变量写入文件，supervisor 的 fastcgi 程序从中读取
CMD ["bash", "-c", "env | grep ^DB_ > /etc/dbenv && exec /usr/bin/supervisord -c /etc/supervisord.conf"]
