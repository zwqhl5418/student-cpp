#!/bin/bash
# 学生成绩管理系统 — 离线部署包打包脚本
# 生成可在 CentOS 7.6 私网机器上直接编译运行的完整包
#
# 用法:
#   ./pack.sh            # 生成 .tar.gz
#   ./pack.sh --dir      # 生成目录（不压缩，便于检查）

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
PACK_NAME="student-grades-deploy-${TIMESTAMP}"
OUTPUT_DIR="${SCRIPT_DIR}/pack-out/${PACK_NAME}"

echo "=== 打包学生成绩管理系统离线部署包 ==="
echo ""

# 清理旧输出
rm -rf "${SCRIPT_DIR}/pack-out"
mkdir -p "${OUTPUT_DIR}"

# ─── 复制文件 ────────────────────────────────────────────────────
echo "[1/4] 复制源文件..."

# 源码
cp -r "${SCRIPT_DIR}/src" "${OUTPUT_DIR}/"

# vendored 头文件（保留完整 include/ 目录）
cp -r "${SCRIPT_DIR}/include" "${OUTPUT_DIR}/"

# vendored 库文件
mkdir -p "${OUTPUT_DIR}/lib"
cp "${SCRIPT_DIR}/lib/libpq.so.5.16" "${OUTPUT_DIR}/lib/" 2>/dev/null || true
cp "${SCRIPT_DIR}/lib/libfcgi.a"     "${OUTPUT_DIR}/lib/" 2>/dev/null || true
cp "${SCRIPT_DIR}/lib/libfcgi++.a"   "${OUTPUT_DIR}/lib/" 2>/dev/null || true
cp "${SCRIPT_DIR}/lib/libfcgi.so.0.0.0"   "${OUTPUT_DIR}/lib/" 2>/dev/null || true
cp "${SCRIPT_DIR}/lib/libfcgi++.so.0.0.0" "${OUTPUT_DIR}/lib/" 2>/dev/null || true
# 创建正确的相对符号链接（而非拷贝可能失效的链接）
cd "${OUTPUT_DIR}/lib"
ln -sf libpq.so.5.16 libpq.so.5
ln -sf libpq.so.5 libpq.so
ln -sf libfcgi.so.0.0.0   libfcgi.so.0 2>/dev/null || true
ln -sf libfcgi.so.0       libfcgi.so   2>/dev/null || true
ln -sf libfcgi++.so.0.0.0 libfcgi++.so.0 2>/dev/null || true
ln -sf libfcgi++.so.0     libfcgi++.so   2>/dev/null || true
cd "${SCRIPT_DIR}"

# 数据库初始化脚本（放在 deploy/db/，start.sh 同级读取）
mkdir -p "${OUTPUT_DIR}/deploy/db"
cp "${SCRIPT_DIR}/db/01-schema.sql" "${OUTPUT_DIR}/deploy/db/"
cp "${SCRIPT_DIR}/db/02-seed.sql"   "${OUTPUT_DIR}/deploy/db/"

# 构建系统
cp "${SCRIPT_DIR}/Makefile" "${OUTPUT_DIR}/"

# 部署脚本
mkdir -p "${OUTPUT_DIR}/deploy"
cp "${SCRIPT_DIR}/deploy/start.sh"  "${OUTPUT_DIR}/deploy/"
cp "${SCRIPT_DIR}/deploy/stop.sh"   "${OUTPUT_DIR}/deploy/"
cp "${SCRIPT_DIR}/deploy/README.md" "${OUTPUT_DIR}/deploy/"
# PG 离线安装辅助（opt/）
mkdir -p "${OUTPUT_DIR}/deploy/opt"
cp "${SCRIPT_DIR}/deploy/opt/download-pg-rpms.sh"           "${OUTPUT_DIR}/deploy/opt/" 2>/dev/null || true
cp "${SCRIPT_DIR}/deploy/opt/pgdg-redhat-repo-latest.noarch.rpm" "${OUTPUT_DIR}/deploy/opt/" 2>/dev/null || true

echo "[2/4] 设置权限..."
chmod +x "${OUTPUT_DIR}/deploy/start.sh"
chmod +x "${OUTPUT_DIR}/deploy/stop.sh"
chmod +x "${OUTPUT_DIR}/deploy/opt/download-pg-rpms.sh" 2>/dev/null || true

echo "[3/4] 写入快速入门..."
cat > "${OUTPUT_DIR}/QUICKSTART.txt" << 'QUICKSTART'
============================================================
  学生成绩管理系统 — 离线部署快速入门
  方案 A：cpp-httplib 独立 HTTP（C++11）
  目标平台：CentOS 7.6 x86_64
============================================================

一、准备（在目标机器上执行一次）

  1. 确保 g++ 和 make 可用：
     which g++ make || yum install gcc-c++ make

  2. 同步本地 libpq（如果系统已装 postgresql-libs）：
     make setup-libpq

     如果系统未装 libpq，先从同版本 CentOS 7.6 机器获取：
     scp centos76:/usr/lib64/libpq.so.5 lib/libpq.so.5.16

  3. 自检环境：
     make check-offline

二、编译

  make SCHEME=A -j$(nproc)

  备选（使用系统 libpq）：
  make SCHEME=A PQ_FROM=system -j$(nproc)

三、部署

  cp build/app_a deploy/
  cd deploy

  export DB_HOST=你的PG地址
  export DB_PORT=5432
  export DB_NAME=student_grades
  export DB_USER=student_app
  export DB_PASSWORD=student_pass

  ./start.sh          # 启动（自动等待 PG、初始化 DB）
  curl http://localhost:8080/
  ./stop.sh           # 停止

四、自带 PostgreSQL（可选）

  见 deploy/opt/download-pg-rpms.sh — 在联网机器上下载 PG RPM
  见 deploy/README.md 场景 B — 完整离线安装步骤

五、目录速览

  src/            源码（C++11，~950 行）
  include/        所有 vendored 头文件（httplib, libpq, fcgi）
  lib/            vendored 运行时库（libpq.so, libfcgi）
  db/             数据库建表 + 种子数据 SQL
  deploy/         启动/停止脚本 + 离线部署文档
  Makefile        构建配置（支持 check-offline, setup-libpq）
QUICKSTART

echo "[4/4] 打包..."
cd "${SCRIPT_DIR}/pack-out"

if [ "${1:-}" = "--dir" ]; then
  echo ""
  echo "=== 打包完成（目录模式）==="
  echo "  位置: ${OUTPUT_DIR}"
  echo "  大小: $(du -sh "${OUTPUT_DIR}" | awk '{print $1}')"
  echo ""
  echo "  验证步骤:"
  echo "    cd ${OUTPUT_DIR}"
  echo "    make check-offline"
  echo "    make SCHEME=A -j\$(nproc)"
  exit 0
fi

tar czf "${SCRIPT_DIR}/${PACK_NAME}.tar.gz" "${PACK_NAME}"
cd "${SCRIPT_DIR}"

echo ""
echo "=== 打包完成 ==="
echo "  文件: ${PACK_NAME}.tar.gz"
echo "  大小: $(du -sh "${PACK_NAME}.tar.gz" | awk '{print $1}')"
echo ""
echo "  内容预览:"
tar tzf "${PACK_NAME}.tar.gz" | head -30
echo "  ... ($(tar tzf "${PACK_NAME}.tar.gz" | wc -l) 个文件)"
echo ""
echo "  部署步骤:"
echo "    scp ${PACK_NAME}.tar.gz user@target:/opt/"
echo "    ssh user@target"
echo "    cd /opt && tar xzf ${PACK_NAME}.tar.gz"
echo "    cd ${PACK_NAME}"
echo "    cat QUICKSTART.txt"
