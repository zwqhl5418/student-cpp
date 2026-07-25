// 学生成绩管理系统 — A 方案入口（cpp-httplib 独立 HTTP 服务）
// 直接监听 HTTP 端口，不需要 Nginx

#include <cstdlib>
#include <iostream>
#include <string>

#include "config.h"
#include "dao.h"
#include "handler.h"
#include "httplib.h"
#include "models.h"

int main() {
  // 加载配置
  DbConfig config = LoadDbConfig();

  // 连接数据库
  std::cerr << "[main_a] 正在连接数据库 " << config.host << "...\n";
  if (!ConnectDb(config)) {
    std::cerr << "[main_a] 数据库连接失败，请检查配置\n";
    return 1;
  }
  std::cerr << "[main_a] 数据库连接成功\n";

  // 读取 HTTP 端口
  const char* portStr = std::getenv("HTTP_PORT");
  int port = 8080;
  if (portStr != nullptr && portStr[0] != '\0') {
    port = std::atoi(portStr);
  }

  // 创建 HTTP 服务器
  httplib::Server svr;

  // 注册路由: GET /
  svr.Get("/", [](const httplib::Request& req, httplib::Response& res) {
    // 解析 class 参数（cpp-httplib 已做 URL 解码）
    std::string classFilter;
    if (req.has_param("class")) {
      classFilter = req.get_param_value("class");
    }

    // 处理请求
    std::string html = HandleIndex(classFilter);

    // 设置响应
    res.set_content(html, "text/html; charset=UTF-8");
  });

  // 启动服务
  std::cerr << "[main_a] 服务已启动: http://0.0.0.0:" << port << "\n";
  svr.listen("0.0.0.0", port);

  // 清理
  DisconnectDb();
  return 0;
}
