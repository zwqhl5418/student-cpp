### Task 1: 项目脚手架

**Files:**
- Create: `Makefile`
- Create: `test/Makefile`
- Create: `.gitignore`
- Create: `src/` (directory)
- Create: `include/` (directory)
- Create: `test/` (directory)
- Create: `build/` (directory, via Makefile)

**Interfaces:**
- Produces: `make SCHEME=A` 编译 `build/app_a`，`make SCHEME=D` 编译 `build/app_d`，`make clean` 清理

- [ ] **Step 1: 创建目录结构**

```bash
mkdir -p src include test build
```

- [ ] **Step 2: 创建 .gitignore**

```bash
cat > .gitignore << 'GITIGNORE'
build/
*.o
*.d
app_a
app_d
coverage.info
coverage_html/
.vscode/
*.swp
GITIGNORE
```

- [ ] **Step 3: 创建顶层 Makefile**

写入以下内容到 `Makefile`：

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
```

- [ ] **Step 4: 创建 test/Makefile**

写入以下内容到 `test/Makefile`：

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

- [ ] **Step 5: 验证**

```bash
make SCHEME=A 2>&1 | head -5
# 预期: 无报错（虽然 src/*.cpp 不存在，但 Make 在链接阶段才报错）
# 实际会报 "No rule to make target 'src/handler.cpp'" — 这是预期行为，表示 Makefile 语法正确
```

---

