#!/bin/bash
# PostgreSQL 14 离线 RPM 下载脚本
# 在可以访问外网的 CentOS 7.6 机器上运行
#
# 用法:
#   chmod +x download-pg-rpms.sh
#   ./download-pg-rpms.sh
#
# 输出:
#   pg_rpms/  目录，包含 PostgreSQL 14 全家桶 RPM 包
#
# 说明:
#   将这个脚本和下载好的 RPM 包拷贝到私网机器上，
#   私网机器执行: rpm -ivh pg_rpms/*.rpm

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OUTPUT_DIR="${SCRIPT_DIR}/pg_rpms"

echo "============================================"
echo " PostgreSQL 14 — CentOS 7.6 离线 RPM 下载"
echo "============================================"
echo ""

# 检查操作系统
if [ ! -f /etc/redhat-release ]; then
  echo "错误: 此脚本仅适用于 RHEL/CentOS 系统"
  exit 1
fi
echo "系统: $(cat /etc/redhat-release)"

# 安装 PG yum 仓库
echo ""
echo "[1/3] 安装 PostgreSQL yum 仓库 ..."
if [ -f "${SCRIPT_DIR}/pgdg-redhat-repo-latest.noarch.rpm" ]; then
  sudo rpm -ivh "${SCRIPT_DIR}/pgdg-redhat-repo-latest.noarch.rpm" || true
else
  sudo yum install -y https://download.postgresql.org/pub/repos/yum/reporpms/EL-7-x86_64/pgdg-redhat-repo-latest.noarch.rpm
fi

# 下载（不安装）
mkdir -p "${OUTPUT_DIR}"

echo ""
echo "[2/3] 下载 PostgreSQL 14 RPM 包 ..."
sudo yum install -y --downloadonly --downloaddir="${OUTPUT_DIR}" \
  postgresql14 \
  postgresql14-server \
  postgresql14-libs

echo ""
echo "[3/3] 下载完成，清理仓库缓存"
sudo yum clean all 2>/dev/null || true

echo ""
echo "============================================"
echo " 完成！文件列表:"
echo "============================================"
echo ""
ls -lh "${OUTPUT_DIR}/"
echo ""
echo "总大小: $(du -sh "${OUTPUT_DIR}" | awk '{print $1}')"
echo ""
echo "下一步: 将 ${OUTPUT_DIR} 整个目录拷贝到私网机器，"
echo "然后在私网机器上执行:"
echo "  cd deploy/opt/pg_rpms"
echo "  sudo rpm -ivh *.rpm"
echo ""
echo "安装后初始化 PostgreSQL:"
echo "  sudo /usr/pgsql-14/bin/postgresql-14-setup initdb"
echo "  sudo systemctl enable postgresql-14"
echo "  sudo systemctl start postgresql-14"
