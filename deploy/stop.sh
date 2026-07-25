#!/bin/bash
# 学生成绩管理系统 — 停止脚本（方案 A：cpp-httplib 独立 HTTP）
#
# 用法:
#   ./stop.sh              # 优雅关闭（等待最多 10s）
#   ./stop.sh -f           # 立即强制终止
#   ./stop.sh -t 30        # 等待最多 30s

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PID_FILE="${SCRIPT_DIR}/app_a.pid"
LOG_PREFIX="[stop.sh]"

log()  { echo "${LOG_PREFIX} $*"; }
die()  { log "错误: $*"; exit 1; }

# ─── 参数处理 ──────────────────────────────────────────────────────
FORCE=0
TIMEOUT=10

while [ $# -gt 0 ]; do
  case "$1" in
    -f|--force) FORCE=1; shift ;;
    -t|--timeout) TIMEOUT="$2"; shift 2 ;;
    -h|--help)
      echo "用法: $0 [-f] [-t <秒>]"
      echo "  -f  强制终止 (SIGKILL)"
      echo "  -t  等待超时秒数 (默认 10)"
      exit 0
      ;;
    *) die "未知参数: $1 (使用 -h 查看帮助)" ;;
  esac
done

# ─── 主流程 ────────────────────────────────────────────────────────

if [ ! -f "${PID_FILE}" ]; then
  log "未找到 PID 文件 (${PID_FILE})，app_a 可能未运行"
  exit 0
fi

PID="$(cat "${PID_FILE}" 2>/dev/null || true)"
if [ -z "${PID}" ]; then
  log "PID 文件为空，清理并退出"
  rm -f "${PID_FILE}"
  exit 0
fi

if ! kill -0 "${PID}" 2>/dev/null; then
  log "PID ${PID} 不存在，app_a 可能已退出，清理 PID 文件"
  rm -f "${PID_FILE}"
  exit 0
fi

log "正在停止 app_a (PID ${PID}) ..."

if [ "${FORCE}" = "1" ]; then
  log "强制终止 (SIGKILL)"
  kill -9 "${PID}" 2>/dev/null || true
  rm -f "${PID_FILE}"
  log "已强制终止"
  exit 0
fi

# 优雅关闭
kill "${PID}" 2>/dev/null || true

elapsed=0
while [ $elapsed -lt "${TIMEOUT}" ]; do
  if ! kill -0 "${PID}" 2>/dev/null; then
    log "app_a (PID ${PID}) 已优雅退出"
    rm -f "${PID_FILE}"
    exit 0
  fi
  sleep 1
  elapsed=$((elapsed + 1))
done

# 超时，强制终止
log "app_a 超时未退出 (${TIMEOUT}s)，执行 SIGKILL"
kill -9 "${PID}" 2>/dev/null || true
sleep 1
if kill -0 "${PID}" 2>/dev/null; then
  die "无法终止 PID ${PID}，请检查系统状态"
fi

rm -f "${PID_FILE}"
log "已强制终止"
