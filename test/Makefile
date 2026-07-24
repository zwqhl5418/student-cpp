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
