// 学生成绩管理系统 — 请求处理器
// 解析 HTTP 参数，调度 Service 和 Template

#ifndef SRC_HANDLER_H_
#define SRC_HANDLER_H_

#include <string>

// 处理首页请求
// classFilter: URL 中的 class 查询参数（已 URL 解码）
// 返回完整的 HTML 响应体
std::string HandleIndex(const std::string& classFilter);

#endif  // SRC_HANDLER_H_
