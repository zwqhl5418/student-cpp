// 学生成绩管理系统 — 数据访问层实现
// 使用 libpq 参数化查询防止 SQL 注入

#include "dao.h"

#include <cstdlib>
#include <cstring>
#include <sstream>
#include <stdexcept>
#include <string>
#include <vector>

#include <libpq-fe.h>

namespace {

// 全局数据库连接（单连接模式）
PGconn* g_conn = nullptr;

// 科目列表（应用常量，与 PHP 版保持一致）
const char* kSubjects[] = {"语文", "数学", "英语", "科学"};
const int kSubjectCount = 4;

// 将 PGresult 中的值安全转为字符串
std::string GetString(PGresult* res, int row, int col) {
  if (PQgetisnull(res, row, col)) {
    return "";
  }
  return std::string(PQgetvalue(res, row, col));
}

}  // namespace

bool ConnectDb(const DbConfig& config) {
  std::ostringstream connStr;
  connStr << "host=" << config.host
          << " port=" << config.port
          << " dbname=" << config.dbName
          << " user=" << config.user
          << " password=" << config.password;

  g_conn = PQconnectdb(connStr.str().c_str());
  return PQstatus(g_conn) == CONNECTION_OK;
}

void DisconnectDb() {
  if (g_conn != nullptr) {
    PQfinish(g_conn);
    g_conn = nullptr;
  }
}

std::vector<std::string> QueryClasses() {
  std::vector<std::string> classes;
  if (g_conn == nullptr) return classes;

  PGresult* res = PQexec(g_conn,
      "SELECT DISTINCT class FROM students ORDER BY class");
  if (PQresultStatus(res) != PGRES_TUPLES_OK) {
    PQclear(res);
    return classes;
  }

  int rows = PQntuples(res);
  for (int i = 0; i < rows; ++i) {
    classes.push_back(GetString(res, i, 0));
  }
  PQclear(res);
  return classes;
}

std::vector<PivotRow> QueryPivot(const std::string& classFilter) {
  std::vector<PivotRow> rows;
  if (g_conn == nullptr) return rows;

  // 构建透视查询 SQL
  // 使用 $1 参数化班级筛选，应用常量科目名通过反引号拼接
  std::ostringstream sql;
  sql << "SELECT s.id, s.name, s.class";
  for (int i = 0; i < kSubjectCount; ++i) {
    sql << ", MAX(CASE WHEN sc.subject = '"
        << kSubjects[i]
        << "' THEN sc.score END) AS \"subject_" << i << "\"";
  }
  sql << " FROM students s"
      << " LEFT JOIN scores sc ON s.id = sc.student_id";

  if (!classFilter.empty()) {
    sql << " WHERE s.class = $1";
  }
  sql << " GROUP BY s.id, s.name, s.class"
      << " ORDER BY s.class, s.name";

  // 准备参数
  const char* paramValues[1] = {nullptr};
  if (!classFilter.empty()) {
    paramValues[0] = classFilter.c_str();
  }

  PGresult* res = PQexecParams(
      g_conn,
      sql.str().c_str(),
      classFilter.empty() ? 0 : 1,  // 参数个数
      nullptr,                        // 参数类型（让 PG 推断）
      paramValues,
      nullptr,                        // 参数长度（字符串自动）
      nullptr,                        // 参数格式（文本）
      0                               // 结果格式（文本）
  );

  if (PQresultStatus(res) != PGRES_TUPLES_OK) {
    PQclear(res);
    return rows;
  }

  int rowCount = PQntuples(res);
  for (int r = 0; r < rowCount; ++r) {
    PivotRow row;
    row.studentId   = std::atoi(GetString(res, r, 0).c_str());
    row.studentName = GetString(res, r, 1);
    row.className   = GetString(res, r, 2);

    // 各科成绩（从第 3 列开始）
    for (int i = 0; i < kSubjectCount; ++i) {
      if (!PQgetisnull(res, r, 3 + i)) {
        double score = std::atof(PQgetvalue(res, r, 3 + i));
        row.scores[kSubjects[i]] = score;
      }
      // NULL 的科目不插入 map，Template 层据此显示 "-"
    }
    rows.push_back(row);
  }
  PQclear(res);
  return rows;
}
