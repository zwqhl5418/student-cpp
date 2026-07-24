# Task 1 Report: 项目脚手架

## 1. 创建/修改的文件

| 文件 | 操作 | 说明 |
|------|------|------|
| `src/` | 创建 | 源文件目录 |
| `include/` | 创建 | 头文件目录 |
| `test/` | 创建 | 测试目录，含 `test/Makefile` |
| `.gitignore` | 创建 | 忽略 `build/`, `*.o`, `*.d`, `app_a`, `app_d`, `coverage*`, `.vscode/`, `*.swp` |
| `Makefile` | 创建 | 顶层构建文件，支持 SCHEME=A/D 切换 |
| `test/Makefile` | 创建 | 单元测试构建文件，基于 Google Test |

## 2. 执行的命令及输出

### `make SCHEME=A`

```
make: *** 没有规则可制作目标"build/handler.o"，由"build/app_a" 需求。 停止。
```

预期行为：Makefile 语法正确，但因 `src/handler.cpp` 等源文件尚不存在，编译阶段报错。

### `make SCHEME=D`

```
make: *** 没有规则可制作目标"build/handler.o"，由"build/app_d" 需求。 停止。
```

预期行为同上，SCHEME=D 正确选择了 `app_d` 目标。

### `make clean`

```
rm -rf build
cd test && make clean || true
make[1]: 进入目录".../test"
rm -rf ../build/test
make[1]: 离开目录".../test"
```

`make clean` 正常工作，清理了 `build/` 目录。

## 3. 验证方式

- `make SCHEME=A` 和 `make SCHEME=D` 均因源文件不存在而报 `No rule to make target`——这是预期行为，证明 Makefile 的变量替换、条件判断和规则语法正确
- `make clean` 成功执行，无报错
- 目录结构 `src/`, `include/`, `test/` 均已就位

## 4. 注意事项

无。此任务为纯脚手架搭建，不涉及代码功能。
