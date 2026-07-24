-- 一年一班 2 名学生
INSERT INTO students (name, class) VALUES ('张三', '一年一班');
INSERT INTO students (name, class) VALUES ('李四', '一年一班');

-- 一年二班 2 名学生
INSERT INTO students (name, class) VALUES ('王五', '一年二班');
INSERT INTO students (name, class) VALUES ('赵六', '一年二班');

-- 一年三班 2 名学生
INSERT INTO students (name, class) VALUES ('孙七', '一年三班');
INSERT INTO students (name, class) VALUES ('周八', '一年三班');

-- 成绩数据（每人 4 科）
INSERT INTO scores (student_id, subject, score) VALUES
(1, '语文', 85), (1, '数学', 90), (1, '英语', 78), (1, '科学', 92),
(2, '语文', 88), (2, '数学', 76), (2, '英语', 95), (2, '科学', 81),
(3, '语文', 92), (3, '数学', 88), (3, '英语', 72), (3, '科学', 85),
(4, '语文', 79), (4, '数学', 95), (4, '英语', 88), (4, '科学', 90),
(5, '语文', 85), (5, '数学', 82), (5, '英语', 90), (5, '科学', 78),
(6, '语文', 91), (6, '数学', 87), (6, '英语', 84), (6, '科学', 93);
