<?php
declare(strict_types=1);

// ═══════════════════════════════════════════════════════════════
// Configuration — read from environment, injected by docker-compose
// ═══════════════════════════════════════════════════════════════
$db_host     = getenv('DB_HOST') ?: 'db';
$db_port     = getenv('DB_PORT') ?: '5432';
$db_name     = getenv('DB_NAME') ?: 'student_grades';
$db_user     = getenv('DB_USER') ?: 'student_app';
$db_password = getenv('DB_PASSWORD') ?: 'student_pass';

// Application constant: the four subjects to display as table columns
$subjects = ['语文', '数学', '英语', '科学'];

// ═══════════════════════════════════════════════════════════════
// Extension check — must run before PDO connection attempt
// ═══════════════════════════════════════════════════════════════
if (!extension_loaded('pdo_pgsql')) {
    http_response_code(500);
    ?><!DOCTYPE html>
<html lang="zh-CN">
<head><meta charset="UTF-8"><title>教育成绩数据分析平台</title></head>
<body><h1>教育成绩数据分析平台</h1><p>PDO_PGSQL 扩展未安装</p></body>
</html>
<?php
    exit;
}

// ═══════════════════════════════════════════════════════════════
// Database connection
// ═══════════════════════════════════════════════════════════════
try {
    $dsn = sprintf('pgsql:host=%s;port=%s;dbname=%s', $db_host, $db_port, $db_name);
    $pdo = new PDO($dsn, $db_user, $db_password, [
        PDO::ATTR_ERRMODE            => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
        PDO::ATTR_EMULATE_PREPARES   => false,
    ]);
} catch (PDOException $e) {
    http_response_code(500);
    ?><!DOCTYPE html>
<html lang="zh-CN">
<head><meta charset="UTF-8"><title>教育成绩数据分析平台</title></head>
<body><h1>教育成绩数据分析平台</h1><p>数据库连接失败，请检查配置</p></body>
</html>
<?php
    exit;
}

// ═══════════════════════════════════════════════════════════════
// Page rendering
// ═══════════════════════════════════════════════════════════════
$classFilter = trim($_GET['class'] ?? '');

// 1. Fetch distinct classes for the <select> dropdown
$classes = $pdo->query('SELECT DISTINCT class FROM students ORDER BY class')
               ->fetchAll(PDO::FETCH_COLUMN);

// 2. Build the pivot query with dynamic subject columns
//    Note: subjects are application constants, not user input,
//    so using $pdo->quote() here is safe.
$sql = 'SELECT s.id, s.name, s.class';
foreach ($subjects as $subject) {
    $quoted = $pdo->quote($subject);
    $sql .= sprintf(
        ', MAX(CASE WHEN sc.subject = %s THEN sc.score END) AS "%s"',
        $quoted,
        $subject
    );
}
$sql .= ' FROM students s';
$sql .= ' LEFT JOIN scores sc ON s.id = sc.student_id';

$params = [];
if ($classFilter !== '') {
    $sql .= ' WHERE s.class = :class';
    $params[':class'] = $classFilter;
}
$sql .= ' GROUP BY s.id, s.name, s.class';
$sql .= ' ORDER BY s.class, s.name';

$stmt = $pdo->prepare($sql);
$stmt->execute($params);
$rows = $stmt->fetchAll();

function formatScore(?string $score): string {
    if ($score === null) return '-';
    return str_ends_with($score, '.00') ? substr($score, 0, -3) : $score;
}
?><!DOCTYPE html>
<html lang="zh-CN">
<head>
  <meta charset="UTF-8">
  <title>教育成绩数据分析平台</title>
  <style>
    *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Noto Sans SC", sans-serif;
      color: #e2e8f0; line-height: 1.6; min-height: 100vh;
      background: #0a0e27;
      overflow-x: hidden;
    }
    /* Animated gradient orb layers */
    body::before, body::after {
      content: ''; position: fixed; border-radius: 50%; filter: blur(120px); z-index: 0;
      animation: orbFloat 12s ease-in-out infinite alternate;
    }
    body::before {
      width: 600px; height: 600px;
      background: radial-gradient(circle, rgba(59,130,246,.35) 0%, transparent 70%);
      top: -150px; left: -100px;
    }
    body::after {
      width: 500px; height: 500px;
      background: radial-gradient(circle, rgba(139,92,246,.3) 0%, transparent 70%);
      bottom: -100px; right: -80px;
      animation-delay: -6s;
    }
    @keyframes orbFloat {
      0%   { transform: translate(0,0) scale(1); }
      50%  { transform: translate(60px,-40px) scale(1.25); }
      100% { transform: translate(-30px,30px) scale(1.1); }
    }
    /* Grid overlay */
    .grid-bg {
      position: fixed; inset: 0; z-index: 0; opacity: .06; pointer-events: none;
      background-image:
        linear-gradient(rgba(59,130,246,.5) 1px, transparent 1px),
        linear-gradient(90deg, rgba(59,130,246,.5) 1px, transparent 1px);
      background-size: 60px 60px;
      animation: gridPulse 8s ease-in-out infinite alternate;
    }
    @keyframes gridPulse {
      0%   { opacity: .04; }
      100% { opacity: .1; }
    }
    /* Sci-fi globe */
    .globe-wrap {
      position: fixed; z-index: 0; pointer-events: none;
      top: 50%; left: 50%; transform: translate(-50%,-50%);
      width: 500px; height: 500px;
    }
    .globe {
      position: absolute; inset: 20px; border-radius: 50%;
      background:
        radial-gradient(circle at 35% 35%, rgba(59,130,246,.15) 0%, transparent 50%),
        radial-gradient(circle at 50% 50%, rgba(16,185,129,.08) 0%, transparent 70%);
      box-shadow:
        inset 0 0 80px rgba(59,130,246,.12),
        0 0 60px rgba(37,99,235,.15),
        0 0 120px rgba(37,99,235,.06);
      animation: globePulse 6s ease-in-out infinite alternate;
    }
    /* Wireframe latitude lines */
    .globe::before {
      content: ''; position: absolute; inset: 0; border-radius: 50%;
      background:
        radial-gradient(ellipse 80% 2px at 50% 25%, transparent 49%, rgba(59,130,246,.25) 50%, transparent 51%),
        radial-gradient(ellipse 90% 2px at 50% 50%, transparent 49%, rgba(59,130,246,.2) 50%, transparent 51%),
        radial-gradient(ellipse 80% 2px at 50% 75%, transparent 49%, rgba(59,130,246,.15) 50%, transparent 51%);
    }
    /* Longitude arcs */
    .globe::after {
      content: ''; position: absolute; inset: 0; border-radius: 50%;
      background:
        linear-gradient(90deg, transparent 49.5%, rgba(59,130,246,.15) 50%, transparent 50.5%),
        linear-gradient(150deg, transparent 49.5%, rgba(59,130,246,.1) 50%, transparent 50.5%),
        linear-gradient(30deg, transparent 49.5%, rgba(59,130,246,.1) 50%, transparent 50.5%);
    }
    /* Orbit ring 1 - horizontal */
    .ring { position: absolute; border-radius: 50%; pointer-events: none; }
    .ring-1 {
      inset: -30px; border: 1px solid rgba(59,130,246,.12);
      animation: ringSpin1 20s linear infinite;
      clip-path: polygon(0 0, 100% 0, 100% 60%, 0 60%);
    }
    .ring-2 {
      inset: -50px; border: 1px solid rgba(139,92,246,.08);
      transform: rotateX(70deg);
      animation: ringSpin2 25s linear infinite;
    }
    .ring-3 {
      inset: -15px; border: 1px solid rgba(16,185,129,.1);
      transform: rotateY(60deg);
      animation: ringSpin3 18s linear infinite;
    }
    /* Small orbiting dot */
    .ring-1::after {
      content: ''; position: absolute; width: 6px; height: 6px;
      background: rgba(96,165,250,.8); border-radius: 50%;
      top: -3px; left: 50%;
      box-shadow: 0 0 8px rgba(59,130,246,.6);
    }
    @keyframes globePulse {
      0%   { box-shadow: inset 0 0 80px rgba(59,130,246,.12), 0 0 60px rgba(37,99,235,.15), 0 0 120px rgba(37,99,235,.06); }
      100% { box-shadow: inset 0 0 100px rgba(59,130,246,.18), 0 0 80px rgba(37,99,235,.2), 0 0 160px rgba(37,99,235,.1); }
    }
    @keyframes ringSpin1 { 0% { transform: rotateX(75deg) rotateZ(0deg); } 100% { transform: rotateX(75deg) rotateZ(360deg); } }
    @keyframes ringSpin2 { 0% { transform: rotateX(70deg) rotateZ(0deg); } 100% { transform: rotateX(70deg) rotateZ(-360deg); } }
    @keyframes ringSpin3 { 0% { transform: rotateY(60deg) rotateZ(0deg); } 100% { transform: rotateY(60deg) rotateZ(360deg); } }
    .header {
      position: relative; z-index: 1;
      background: rgba(15,23,42,.75); backdrop-filter: blur(16px);
      color: #e2e8f0; padding: 24px 0; text-align: center;
      box-shadow: 0 1px 0 rgba(59,130,246,.15), 0 4px 24px rgba(0,0,0,.3);
      border-bottom: 1px solid rgba(59,130,246,.1);
    }
    .header h1 { font-size: 1.5rem; font-weight: 500; letter-spacing: .06em; }
    .container { position: relative; z-index: 1; max-width: 960px; margin: 0 auto; padding: 28px 20px; }
    .filter-bar {
      background: rgba(15,23,42,.85); backdrop-filter: blur(12px);
      border-radius: 10px; padding: 16px 20px; margin-bottom: 20px;
      display: flex; align-items: center; gap: 10px;
      box-shadow: 0 4px 16px rgba(0,0,0,.3); border: 1px solid rgba(59,130,246,.15);
    }
    .filter-bar label { font-weight: 500; white-space: nowrap; color: #94a3b8; }
    .filter-bar select {
      flex: 1; max-width: 220px; padding: 8px 12px;
      border: 1px solid rgba(59,130,246,.3); border-radius: 6px;
      font-size: .95rem; background: rgba(30,41,59,.8); color: #e2e8f0;
    }
    .filter-bar button {
      padding: 8px 20px; background: linear-gradient(135deg, #2563eb, #3b82f6);
      color: #fff; border: none; border-radius: 6px; font-size: .95rem;
      cursor: pointer; transition: all .2s; box-shadow: 0 2px 8px rgba(37,99,235,.3);
    }
    .filter-bar button:hover { background: linear-gradient(135deg, #1d4ed8, #2563eb); transform: translateY(-1px); box-shadow: 0 4px 16px rgba(37,99,235,.4); }
    .empty-state { text-align: center; padding: 60px 20px; color: #64748b; font-size: 1.1rem; }
    table {
      width: 100%; border-collapse: collapse;
      background: rgba(15,23,42,.85); backdrop-filter: blur(12px);
      border-radius: 10px; overflow: hidden;
      box-shadow: 0 4px 24px rgba(0,0,0,.3); border: 1px solid rgba(59,130,246,.12);
    }
    thead { background: linear-gradient(135deg, rgba(30,58,138,.95), rgba(37,99,235,.85)); color: #fff; }
    th { padding: 14px 18px; text-align: left; font-weight: 500; font-size: .9rem; letter-spacing: .03em; text-transform: uppercase; }
    td { padding: 12px 18px; border-bottom: 1px solid rgba(59,130,246,.08); color: #cbd5e1; }
    tbody tr { transition: background .2s; }
    tbody tr:nth-child(even) { background: rgba(30,41,59,.4); }
    tbody tr:hover { background: rgba(37,99,235,.15); }
    tbody td:first-child { font-weight: 500; color: #e2e8f0; }
    tbody td:not(:first-child):not(:nth-child(2)) { text-align: center; font-variant-numeric: tabular-nums; }
  </style>
</head>
<body>
  <div class="grid-bg"></div>
  <div class="globe-wrap">
    <div class="globe"></div>
    <div class="ring ring-1"></div>
    <div class="ring ring-2"></div>
    <div class="ring ring-3"></div>
  </div>
  <div class="header"><h1>教育成绩数据分析平台</h1></div>
  <div class="container">

  <!-- Class filter -->
  <form method="GET" class="filter-bar">
    <label>班级筛选：</label>
    <select name="class" onchange="this.form.submit()">
      <option value="">全部班级</option>
<?php foreach ($classes as $c): ?>
      <option value="<?= htmlspecialchars($c, ENT_QUOTES, 'UTF-8') ?>"<?= $c === $classFilter ? ' selected' : '' ?>><?= htmlspecialchars($c, ENT_QUOTES, 'UTF-8') ?></option>
<?php endforeach; ?>
    </select>
    <button type="submit">筛选</button>
  </form>

<?php if (empty($rows)): ?>
  <div class="empty-state">暂无成绩数据</div>
<?php else: ?>
  <table>
    <thead>
      <tr>
        <th>姓名</th>
        <th>班级</th>
<?php foreach ($subjects as $subject): ?>
        <th><?= htmlspecialchars($subject, ENT_QUOTES, 'UTF-8') ?></th>
<?php endforeach; ?>
      </tr>
    </thead>
    <tbody>
<?php foreach ($rows as $row): ?>
      <tr>
        <td><?= htmlspecialchars($row['name'], ENT_QUOTES, 'UTF-8') ?></td>
        <td><?= htmlspecialchars($row['class'], ENT_QUOTES, 'UTF-8') ?></td>
<?php foreach ($subjects as $subject): ?>
        <td><?= htmlspecialchars(formatScore($row[$subject]), ENT_QUOTES, 'UTF-8') ?></td>
<?php endforeach; ?>
      </tr>
<?php endforeach; ?>
    </tbody>
  </table>
<?php endif; ?>
  </div>
</body>
</html>
