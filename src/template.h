// 学生成绩管理系统 — HTML 模板渲染
// 渲染成绩透视表页面，完全复刻现有深色科幻主题样式

#ifndef SRC_TEMPLATE_H_
#define SRC_TEMPLATE_H_

#include <string>
#include <vector>

#include "models.h"

// 渲染完整 HTML 页面
// classes: 班级列表（用于下拉框）
// rows: 成绩透视数据
// selectedClass: 当前筛选的班级（空字符串表示全部）
std::string RenderPage(
    const std::vector<std::string>& classes,
    const std::vector<PivotRow>& rows,
    const std::string& selectedClass);

#endif  // SRC_TEMPLATE_H_
