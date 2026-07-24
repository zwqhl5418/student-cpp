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

.PHONY: all clean

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
