# Task 7: 请求处理器 (Handler) — 实现报告

## 1. 创建的文件

| 文件 | 路径 |
|------|------|
| 头文件 | `/home/fh/exame_test2/src/handler.h` |
| 实现文件 | `/home/fh/exame_test2/src/handler.cpp` |

## 2. 编译验证

```bash
g++ -std=c++11 -Wall -Wextra -Isrc -c src/handler.cpp -o build/handler.o
```

- 结果：编译成功，产生 `build/handler.o` (28968 bytes)
- 警告/错误：0

## 3. 实现说明

`HandleIndex()` 是一个薄委托层，按以下顺序执行：

1. 调用 `GetClasses()` 获取班级列表
2. 调用 `GetStudentScores(classFilter)` 获取筛选后的成绩透视数据
3. 调用 `RenderPage(classes, rows, classFilter)` 生成完整 HTML

## 4. 提交

```
[master 9b1fd66] Task 7: request handler (param parsing + dispatch)
 2 files changed, 35 insertions(+)
 create mode 100644 src/handler.cpp
 create mode 100644 src/handler.h
```
