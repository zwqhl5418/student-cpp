// 学生成绩管理系统 — D 方案入口（FastCGI + Nginx）
// 通过 FastCGI 协议与 Nginx 通信，复用现有前端架构

#include <cstdlib>
#include <iostream>
#include <string>

#include "config.h"
#include "dao.h"
#include "handler.h"
#include "models.h"

#ifdef BUILD_SCHEME_D
#include <fcgio.h>

namespace {

// 解析 FastCGI QUERY_STRING 中的 class 参数
std::string ParseClassParam(const char* queryString) {
  if (queryString == nullptr) return "";
  const std::string query(queryString);
  const std::string key = "class=";
  size_t pos = query.find(key);
  if (pos == std::string::npos) return "";
  pos += key.size();
  size_t end = query.find('&', pos);
  return query.substr(pos, end == std::string::npos ? end : end - pos);
}

}  // namespace

int main() {
  // 加载配置
  DbConfig config = LoadDbConfig();

  // 连接数据库
  std::cerr << "[main_d] 正在连接数据库 " << config.host << "...\n";
  if (!ConnectDb(config)) {
    std::cerr << "[main_d] 数据库连接失败，请检查配置\n";
    return 1;
  }
  std::cerr << "[main_d] 数据库连接成功\n";

  // 初始化 FastCGI
  FCGX_Request request;
  FCGX_Init();
  FCGX_InitRequest(&request, 0, 0);

  std::cerr << "[main_d] FastCGI 服务已启动，等待请求...\n";

  // Accept 循环
  while (FCGX_Accept_r(&request) == 0) {
    // 解析 class 查询参数
    const char* queryString = FCGX_GetParam("QUERY_STRING", request.envp);
    std::string classFilter = ParseClassParam(queryString);

    // 处理请求
    std::string html = HandleIndex(classFilter);

    // 输出 HTTP 响应（注意：libfcgi 的 printf 不完全支持 C99 格式符如 %zu，
    // 因此使用 %lu 并显式转型为 unsigned long，或直接省略 Content-Length）
    FCGX_FPrintF(request.out,
        "Content-Type: text/html; charset=UTF-8\r\n"
        "\r\n"
        "%s",
        html.c_str());
  }

  // 清理
  DisconnectDb();
  return 0;
}
#else
// 非 D 方案编译时提供占位 main，防止链接报错
int main() {
  std::cerr << "Error: D scheme not enabled. Use 'make SCHEME=D'.\n";
  return 1;
}
#endif  // BUILD_SCHEME_D
