# 学生成绩管理系统 — GNU Make 构建配置
# 支持在线/离线编译，C++11，gcc 4.8.5+，CentOS 7.6 / Debian
#
# 快速开始:
#   make SCHEME=A              # 离线编译方案 A（默认，使用 vendored 依赖）
#   make check-offline         # 编译前自检
#
# 方案选择:
#   SCHEME=A   cpp-httplib 独立 HTTP 服务（默认）
#   SCHEME=D   FastCGI + Nginx 模式
#
# libpq 来源:
#   PQ_FROM=vendor   使用仓库 lib/ 中的 vendored libpq（默认，无需安装 PG 包）
#   PQ_FROM=system   使用系统安装的 libpq（需 yum install postgresql-libs）
#
# 示例:
#   make SCHEME=A -j$(nproc)                     # 离线编译，vendored 依赖
#   make SCHEME=A PQ_FROM=system -j$(nproc)      # 使用系统 libpq
#   make SCHEME=D -j$(nproc)                     # FastCGI 模式
#   make check-offline                           # 环境自检

SCHEME    ?= A
PQ_FROM   ?= vendor

CXX       := g++
CXXFLAGS  := -std=c++11 -Wall -Wextra -O2
INCLUDES  := -Isrc -Iinclude

BUILD_DIR := build
TARGET    := $(BUILD_DIR)/app_a
SRCS      := src/handler.cpp src/service.cpp src/dao.cpp \
             src/template.cpp src/config.cpp

# ─── libpq 来源配置 ────────────────────────────────────────────────
ifeq ($(PQ_FROM), vendor)
  # 使用仓库内 vendored libpq（零外部依赖，私网友好）
  PQ_LDFLAGS := -Llib -lpq -Wl,-rpath,'$$ORIGIN/lib'
else
  # 使用系统安装的 libpq
  PQ_LDFLAGS := -lpq
endif

LDFLAGS := -lpthread $(PQ_LDFLAGS)

# ─── 方案选择 ──────────────────────────────────────────────────────
ifeq ($(SCHEME), D)
  TARGET   := $(BUILD_DIR)/app_d
  SRCS     += src/main_d.cpp
  CXXFLAGS += -DBUILD_SCHEME_D
  LDFLAGS  += -lfcgi -lfcgi++
else
  SRCS     += src/main_a.cpp
endif

OBJS := $(SRCS:src/%.cpp=$(BUILD_DIR)/%.o)
DEPS := $(OBJS:.o=.d)

.PHONY: all clean check-offline build-offline

all: $(TARGET)

# ─── 编译与链接 ────────────────────────────────────────────────────
$(TARGET): $(OBJS)
	@mkdir -p $(BUILD_DIR)
	$(CXX) $(CXXFLAGS) -o $@ $^ $(LDFLAGS)

$(BUILD_DIR)/%.o: src/%.cpp
	@mkdir -p $(BUILD_DIR)
	$(CXX) $(CXXFLAGS) $(INCLUDES) -MMD -MP -c $< -o $@

# ─── 辅助：从当前系统提取 libpq 到 vendored 目录 ─────────────────
# 在目标平台上运行一次，确保 lib/ 中的 libpq.so 与当前 OS ABI 匹配
setup-libpq:
	@echo "=== 从系统提取 libpq.so 到 lib/ ==="
	@SYSTEM_PQ=$$(ldconfig -p 2>/dev/null | grep libpq.so.5 | head -1 | awk '{print $$NF}'); \
	if [ -z "$$SYSTEM_PQ" ]; then \
	  echo "[FAIL] 系统中未找到 libpq.so.5"; \
	  echo "  请先安装: yum install postgresql-libs (或 postgresql14-libs)"; \
	  exit 1; \
	fi; \
	REAL_PQ=$$(readlink -f "$$SYSTEM_PQ"); \
	if [ ! -f "$$REAL_PQ" ]; then \
	  echo "[FAIL] 无法解析 $$SYSTEM_PQ"; \
	  exit 1; \
	fi; \
	cp "$$REAL_PQ" lib/libpq.so.5.16; \
	chmod 644 lib/libpq.so.5.16; \
	ln -sf libpq.so.5.16 lib/libpq.so.5; \
	ln -sf libpq.so.5 lib/libpq.so; \
	echo "[OK] $$REAL_PQ → lib/libpq.so.5.16"; \
	echo "[OK] lib/libpq.so.5 → libpq.so.5.16"; \
	echo "[OK] lib/libpq.so → libpq.so.5"; \
	echo "=== 完成 ==="

# ─── 离线编译自检（在 make 前运行，确保环境完整）─────────────────
check-offline:
	@echo "=== 离线编译环境自检 ==="
	@# 编译器
	@if command -v $(CXX) >/dev/null 2>&1; then \
	  echo "[OK] 编译器: $$($(CXX) --version | head -1)"; \
	else \
	  echo "[FAIL] 未找到 $(CXX)，请安装: yum install gcc-c++"; \
	fi
	@# C++11 支持
	@if echo 'int main(){}' | $(CXX) -std=c++11 -x c++ - -o /dev/null 2>/dev/null; then \
	  echo "[OK] C++11 支持"; \
	else \
	  echo "[FAIL] $(CXX) 不支持 -std=c++11"; \
	fi
	@# vendored 头文件
	@if [ -f include/httplib.h ]; then \
	  echo "[OK] include/httplib.h (vendored)"; \
	else \
	  echo "[FAIL] include/httplib.h 缺失"; \
	fi
	@if [ -f include/libpq-fe.h ]; then \
	  echo "[OK] include/libpq-fe.h (vendored)"; \
	else \
	  echo "[FAIL] include/libpq-fe.h 缺失"; \
	fi
	@# vendored 库文件
	@if [ "$(PQ_FROM)" = "vendor" ]; then \
	  if [ -f lib/libpq.so ]; then \
	    echo "[OK] lib/libpq.so (vendored)"; \
	    echo "     $$(ls -lh lib/libpq.so.5.16 2>/dev/null | awk '{print $$5,$$NF}')"; \
	  else \
	    echo "[FAIL] lib/libpq.so 缺失，请先放入 CentOS 7.6 版 libpq.so.5"; \
	  fi; \
	else \
	  echo "[INFO] PQ_FROM=system，使用系统 libpq"; \
	fi
	@# 编译测试
	@echo 'int main(){}' | $(CXX) $(CXXFLAGS) -x c++ - -o /tmp/_check_offline_build 2>/dev/null \
	  && rm -f /tmp/_check_offline_build \
	  && echo "[OK] 编译器可正常工作" \
	  || echo "[FAIL] 编译器无法生成二进制"
	@# 链接测试（vendored 模式）
	@if [ "$(PQ_FROM)" = "vendor" ]; then \
	  printf '#include <libpq-fe.h>\nint main(){PQlibVersion();return 0;}' | \
	    $(CXX) $(CXXFLAGS) $(INCLUDES) -x c++ - -o /tmp/_check_link $(LDFLAGS) 2>/dev/null \
	    && rm -f /tmp/_check_link && echo "[OK] 可与 vendored libpq 成功链接" \
	    || { rm -f /tmp/_check_link; echo "[WARN] 与 vendored libpq 链接失败"; \
	         echo "       库可能来自其他 OS，请替换为当前平台的 libpq.so.5"; \
	         echo "       或使用 make SCHEME=A PQ_FROM=system"; }; \
	fi
	@# vendored libpq 运行时依赖检查（防止 Debian libpq 在 CentOS 7.6 运行时崩溃）
	@if [ "$(PQ_FROM)" = "vendor" ] && [ -f lib/libpq.so.5.16 ]; then \
	  MISSING=$$(ldd lib/libpq.so.5.16 2>/dev/null | grep 'not found' | awk '{print $$1}' || true); \
	  if [ -n "$$MISSING" ]; then \
	    echo "[WARN] vendored libpq 缺少运行时依赖:"; \
	    for lib in $$MISSING; do echo "       - $$lib"; done; \
	    echo "       libpq.so.5.16 可能是从其他 OS 拷贝的 (如 Debian)"; \
	    echo "       编译可通过，但二进制运行时将崩溃!"; \
	    echo "       请运行: make setup-libpq"; \
	    echo "       或使用: make SCHEME=A PQ_FROM=system"; \
	  else \
	    echo "[OK] vendored libpq 运行时依赖完整"; \
	  fi; \
	fi
	@echo "=== 自检完成 ==="

# ─── 离线编译 ──────────────────────────────────────────────────────
# 等同于 make SCHEME=A PQ_FROM=vendor，先自检再编译
build-offline: check-offline
	@echo ""
	@echo "=== 开始离线编译 (SCHEME=A, PQ_FROM=vendor) ==="
	@$(MAKE) SCHEME=A PQ_FROM=vendor

# ─── 清理 ──────────────────────────────────────────────────────────
clean:
	rm -rf $(BUILD_DIR)
	cd test && $(MAKE) clean || true

# ─── 单元测试（需要 PostgreSQL 可用 + gtest 已安装）───────────────
test: $(TARGET)
	cd test && $(MAKE)

# 引入自动生成的依赖文件
-include $(DEPS)
