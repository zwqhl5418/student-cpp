#!/bin/bash
# 学生成绩管理系统 — 启动脚本（方案 A：cpp-httplib 独立 HTTP）
# 适用环境: CentOS 7.6 私网离线部署
#
# 用法:
#   export DB_HOST=192.168.1.100          # PG 地址
#   export DB_ADMIN_PASSWORD=postpass     # PG 管理员密码（仅首次需要）
#   ./start.sh
#
# 环境变量:
#   DB_HOST              PG 主机地址 (默认 localhost)
#   DB_PORT              PG 端口 (默认 5432)
#   DB_NAME              应用数据库名 (默认 student_grades)
#   DB_USER              应用数据库用户 (默认 student_app)
#   DB_PASSWORD          应用数据库密码 (默认 student_pass)
#   DB_ADMIN_USER        PG 管理员用户 (默认 postgres)
#   DB_ADMIN_PASSWORD    PG 管理员密码 (首次初始化建库建用户需要)
#   HTTP_PORT            监听端口 (默认 8080)
#   PSQL_CMD             psql 可执行文件 (默认 psql，可换 docker exec pg psql)
#   SKIP_DB_SETUP=1      跳过建库建用户
#   SKIP_DB_INIT=1       跳过建表和数据初始化
#   FORCE_REINIT=1       强制重新建表（清空已有数据）

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_BIN="${SCRIPT_DIR}/app_a"
PID_FILE="${SCRIPT_DIR}/app_a.pid"
DB_SETUP_MARKER="${SCRIPT_DIR}/.db_setup_done"
DB_INIT_MARKER="${SCRIPT_DIR}/.db_initialized"
LOG_PREFIX="[start.sh]"

# ─── 环境变量默认值 ────────────────────────────────────────────────
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"
DB_NAME="${DB_NAME:-student_grades}"
DB_USER="${DB_USER:-student_app}"
DB_PASSWORD="${DB_PASSWORD:-student_pass}"
DB_ADMIN_USER="${DB_ADMIN_USER:-postgres}"
DB_ADMIN_PASSWORD="${DB_ADMIN_PASSWORD:-}"
HTTP_PORT="${HTTP_PORT:-8080}"
PSQL_CMD="${PSQL_CMD:-psql}"
SKIP_DB_SETUP="${SKIP_DB_SETUP:-0}"
SKIP_DB_INIT="${SKIP_DB_INIT:-0}"
FORCE_REINIT="${FORCE_REINIT:-0}"

# ─── 函数定义 ──────────────────────────────────────────────────────
log()  { echo "${LOG_PREFIX} $*"; }
die()  { log "错误: $*"; exit 1; }

psql_admin() {
  PGPASSWORD="${DB_ADMIN_PASSWORD}" ${PSQL_CMD} \
    -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_ADMIN_USER}" -d postgres \
    "$@"
}

psql_app() {
  PGPASSWORD="${DB_PASSWORD}" ${PSQL_CMD} \
    -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" \
    "$@"
}

check_prereqs() {
  if [ ! -f "${APP_BIN}" ]; then
    die "找不到可执行文件 ${APP_BIN}，请先编译 app_a 并放入 deploy/ 目录"
  fi
  if [ ! -x "${APP_BIN}" ]; then
    die "${APP_BIN} 没有执行权限，请运行: chmod +x ${APP_BIN}"
  fi
}

wait_for_pg() {
  local host="$1" port="$2" timeout_secs="${3:-30}"
  local elapsed=0

  log "等待 PostgreSQL ${host}:${port} ..."

  while [ $elapsed -lt $timeout_secs ]; do
    if timeout 1 bash -c "echo >/dev/tcp/${host}/${port}" 2>/dev/null; then
      log "PostgreSQL 已就绪 (${host}:${port})"
      return 0
    fi
    sleep 1
    elapsed=$((elapsed + 1))
  done

  die "PostgreSQL ${host}:${port} 在 ${timeout_secs}s 内未就绪，请检查数据库服务"
}

# ─── 第一步：创建数据库和用户（需要管理员权限）────────────────────
setup_database() {
  if [ "${SKIP_DB_SETUP}" = "1" ]; then
    log "SKIP_DB_SETUP=1，跳过建库建用户"
    return 0
  fi

  if [ "${FORCE_REINIT}" = "1" ]; then
    log "FORCE_REINIT=1，强制重建数据库和用户"
    rm -f "${DB_SETUP_MARKER}"
  fi

  if [ -f "${DB_SETUP_MARKER}" ]; then
    log "数据库和用户已创建过 (${DB_SETUP_MARKER})，跳过"
    return 0
  fi

  if [ -z "${DB_ADMIN_PASSWORD}" ]; then
    log "未设置 DB_ADMIN_PASSWORD，跳过建库建用户"
    log "  假设数据库 ${DB_NAME} 和用户 ${DB_USER} 已存在"
    return 0
  fi

  log "=== 第一步：创建数据库和用户 ==="

  # ── 建库 ──
  if psql_admin -tAc "SELECT 1 FROM pg_database WHERE datname='${DB_NAME}'" 2>/dev/null | grep -q 1; then
    log "数据库 ${DB_NAME} 已存在，跳过创建"
  else
    log "创建数据库 ${DB_NAME} ..."
    psql_admin -c "CREATE DATABASE \"${DB_NAME}\";" 2>&1 | while IFS= read -r line; do
      log "  [psql] ${line}"
    done
  fi

  # ── 建用户 ──
  if psql_admin -tAc "SELECT 1 FROM pg_roles WHERE rolname='${DB_USER}'" 2>/dev/null | grep -q 1; then
    log "用户 ${DB_USER} 已存在，跳过创建"
  else
    log "创建用户 ${DB_USER} ..."
    psql_admin -c "CREATE USER \"${DB_USER}\" WITH PASSWORD '${DB_PASSWORD}';" 2>&1 | while IFS= read -r line; do
      log "  [psql] ${line}"
    done
    psql_admin -c "GRANT ALL ON DATABASE \"${DB_NAME}\" TO \"${DB_USER}\";" 2>/dev/null
  fi

  touch "${DB_SETUP_MARKER}"
  log "数据库和用户就绪"
}

# ─── 第二步：建表 + 种子数据 ───────────────────────────────────────
init_database() {
  if [ "${SKIP_DB_INIT}" = "1" ]; then
    log "SKIP_DB_INIT=1，跳过建表和种子数据"
    return 0
  fi

  if [ "${FORCE_REINIT}" = "1" ]; then
    rm -f "${DB_INIT_MARKER}"
  fi

  if [ -f "${DB_INIT_MARKER}" ]; then
    log "表结构已初始化过 (${DB_INIT_MARKER})，跳过"
    return 0
  fi

  log "=== 第二步：建表 + 种子数据 ==="

  if ! command -v ${PSQL_CMD} >/dev/null 2>&1; then
    log "警告: 未找到 ${PSQL_CMD} 命令，跳过自动初始化"
    log "请手动执行 db/ 目录下的 SQL 脚本，完成后执行:"
    log "  touch ${DB_INIT_MARKER}"
    return 0
  fi

  log "执行 schema (db/01-schema.sql)..."
  psql_app -f "${SCRIPT_DIR}/db/01-schema.sql" 2>&1 | while IFS= read -r line; do
    log "  [psql] ${line}"
  done
  if [ ${PIPESTATUS[0]} -ne 0 ]; then
    die "schema 初始化失败"
  fi

  log "执行种子数据 (db/02-seed.sql)..."
  psql_app -f "${SCRIPT_DIR}/db/02-seed.sql" 2>&1 | while IFS= read -r line; do
    log "  [psql] ${line}"
  done
  if [ ${PIPESTATUS[0]} -ne 0 ]; then
    die "种子数据导入失败"
  fi

  touch "${DB_INIT_MARKER}"
  log "建表和数据初始化完成"
}

# ─── 清理函数 ──────────────────────────────────────────────────────
cleanup() {
  log "收到停止信号，正在关闭 app_a ..."
  if [ -f "${PID_FILE}" ]; then
    local pid
    pid="$(cat "${PID_FILE}" 2>/dev/null || true)"
    if [ -n "${pid}" ] && kill -0 "${pid}" 2>/dev/null; then
      kill "${pid}"
      for i in $(seq 1 10); do
        if ! kill -0 "${pid}" 2>/dev/null; then
          log "app_a (PID ${pid}) 已优雅退出"
          rm -f "${PID_FILE}"
          exit 0
        fi
        sleep 1
      done
      log "app_a 超时未退出，强制终止"
      kill -9 "${pid}" 2>/dev/null || true
    fi
    rm -f "${PID_FILE}"
  fi
  log "已停止"
  exit 0
}

# ─── 主流程 ────────────────────────────────────────────────────────

# 检查是否已在运行
if [ -f "${PID_FILE}" ]; then
  old_pid="$(cat "${PID_FILE}" 2>/dev/null || true)"
  if [ -n "${old_pid}" ] && kill -0 "${old_pid}" 2>/dev/null; then
    die "app_a 已在运行 (PID ${old_pid})，请先运行 stop.sh"
  fi
  rm -f "${PID_FILE}"
fi

check_prereqs
wait_for_pg "${DB_HOST}" "${DB_PORT}" 30
setup_database
init_database

# 设置信号处理
trap cleanup SIGTERM SIGINT SIGHUP

# 设置库路径（优先使用本地 lib/ 目录）
export LD_LIBRARY_PATH="${SCRIPT_DIR}/lib:${LD_LIBRARY_PATH:-}"

# 启动 app_a
log "=== 启动 app_a ==="
DB_HOST="${DB_HOST}" \
DB_PORT="${DB_PORT}" \
DB_NAME="${DB_NAME}" \
DB_USER="${DB_USER}" \
DB_PASSWORD="${DB_PASSWORD}" \
HTTP_PORT="${HTTP_PORT}" \
"${APP_BIN}" &

APP_PID=$!
echo "${APP_PID}" > "${PID_FILE}"

log "app_a 已启动 (PID ${APP_PID})"
log "访问地址: http://$(hostname -I 2>/dev/null | awk '{print $1}' || echo 'localhost'):${HTTP_PORT}/"

wait "${APP_PID}" || true
log "app_a (PID ${APP_PID}) 已退出"
rm -f "${PID_FILE}"
