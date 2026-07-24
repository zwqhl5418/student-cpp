# 项目名称

一句话说明这个项目是什么，方便 Claude 快速定位项目性质。

## 技术栈
- 语言：C++（C++11 及以下版本）
- 构建系统：GNU Make
- 测试框架：Google Test (gtest)
- 代码格式化：clang-format（Google Style）
- 静态检查：cpplint / clang-tidy

## 常用命令

### 开发
```bash
make SCHEME=A -j$(nproc)       # 编译 A 方案（默认）
make SCHEME=D -j$(nproc)       # 编译 D 方案
make test                       # 运行所有测试
make clean                      # 清理构建产物
```

### 代码检查
```bash
cpplint --recursive src/ include/   # Google 风格检查
clang-format -i <文件路径>          # 格式化单个文件
clang-tidy <文件路径> -- -std=c++11  # 静态分析
```

## 项目结构
- `include/` — 公共头文件（.h / .hpp），对外暴露的接口
- `src/` — 源文件（.cc），按模块划分子目录
- `test/` — 测试文件，与 `src/` 目录结构镜像对应
- `lib/` — 第三方依赖库
- `Makefile` — 顶层构建配置（SCHEME=A|D 切换）

## 编码规范

### 通用规范
- 遵循 **Google C++ Style Guide**（https://google.github.io/styleguide/cppguide.html）
- C++ 标准：**C++11 及以下**，禁止使用 C++14/17/20 特性
- 缩进：2 个空格，禁止使用 Tab
- 每行最多 80 个字符
- 使用 `#pragma once` 或传统的 `#ifndef` / `#define` / `#endif` 头文件保护

### 命名规范（驼峰式）
- **类/结构体**：大驼峰 `class MyClassName {};`
- **函数/方法**：大驼峰 `void DoSomething();`
- **变量**：小驼峰 `int myVariable;`
- **常量/枚举值**：全大写 + 下划线 `const int kMaxSize = 100;` 或以 `k` 开头的大驼峰
- **成员变量**：小驼峰 + 尾部下划线 `int count_;`
- **全局变量**：`g_` 前缀 `int g_globalVar;`
- **宏定义**：全大写 + 下划线 `#define MY_MACRO(x) ...`
- **命名空间**：全小写 + 下划线 `namespace my_namespace {}`
- **文件名**：全小写 + 下划线 `my_class.cc`、`my_class.h`

### 注释规范
- 注释和文档**统一使用中文**
- 文件头注释：说明文件的用途、作者、创建日期
- 类注释：说明类的职责和使用场景
- 函数注释：说明参数、返回值、异常情况
- 复杂逻辑：必须用中文注释解释"为什么这样做"，而非"做了什么"
- 使用 `//` 风格的单行注释，`/* */` 风格仅用于多行注释

### 头文件规范
- 头文件应为 self-contained（自包含），以 `.h` 结尾
- 内联函数仅用于短小（10 行以下）的函数
- `#include` 顺序：相关头文件 → C 系统头 → C++ 标准库 → 其他库 → 本项目头文件
- 避免使用前置声明，优先使用 `#include`

### 类设计规范
- 构造函数中只做简单初始化，复杂逻辑放入 `Init()` 方法
- 若需要自定义析构函数，则必须同时定义或删除拷贝构造和赋值运算符（Rule of Three/Five）
- 优先使用组合而非继承
- 接口类命名以 `Interface` 结尾，抽象基类以 `Base` 结尾

### 其他规范
- 所有函数必须有类型声明（参数和返回值）
- 优先使用 `const` 修饰不修改的变量和成员函数
- 禁止使用 C 风格类型转换，使用 `static_cast`、`const_cast`、`reinterpret_cast`
- 优先使用 `nullptr` 替代 `NULL` 或 `0`
- 禁止在头文件中使用 `using namespace` 指令
- 禁止定义宏函数，优先使用内联函数或模板
- 所有权的指针优先使用 `std::unique_ptr` 或 `std::shared_ptr`（C++11）

## 注意事项
- 禁止修改 `migrations/` 目录下的已有文件，只能新增
- `config/secrets.h` 包含敏感配置，禁止输出其内容到日志或终端
- 新增公共 API 必须同步添加单元测试
- 提交前必须通过 `cpplint` 和 `ctest` 全部检查
- 禁止引入 C++14 及以上标准的特性（如 `std::make_unique` 需自行实现或使用兼容层）
