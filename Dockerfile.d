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
