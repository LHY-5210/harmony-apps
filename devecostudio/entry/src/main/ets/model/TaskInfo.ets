// 任务数据模型与示例任务数据

// 任务实体类
export class TaskInfo {
  id: number = 0;
  title: string = '';        // 任务标题
  course: string = '';       // 所属课程
  deadline: string = '';     // 截止时间
  status: string = '';       // 状态：未开始 / 进行中 / 已完成
  content: string = '';      // 任务详细要求
}

// 路由参数：任务详情页通过 id 查找任务
export interface TaskParams {
  id: number;
}

function makeTask(id: number, title: string, course: string, deadline: string,
  status: string, content: string): TaskInfo {
  const t = new TaskInfo();
  t.id = id;
  t.title = title;
  t.course = course;
  t.deadline = deadline;
  t.status = status;
  t.content = content;
  return t;
}

// 示例任务（教师每次布置的任务可以追加到这里，后续也可改为数据库存储）
export const TASKS: TaskInfo[] = [
  makeTask(1, '实验一：ArkTS 语言基础', 'HarmonyOS 应用开发', '2026-09-20 23:59',
    '进行中', '1. 熟悉 ArkTS 基本语法与类型系统；\n2. 完成一个简单的待办列表 Demo；\n3. 提交源码与实验报告。'),
  makeTask(2, '实验二：ArkUI 页面布局', 'HarmonyOS 应用开发', '2026-09-27 23:59',
    '未开始', '1. 使用 Column/Row/List 等容器完成名片详情页布局；\n2. 掌握 ForEach 列表渲染与自定义组件；\n3. 截图并撰写实验报告。'),
  makeTask(3, '课程大作业：电子名片 App', 'HarmonyOS 应用开发', '2026-10-15 23:59',
    '未开始', '1. 实现名片的增删改查与分组收藏；\n2. 支持 vCard 导入与二维码分享；\n3. 期末进行课堂演示与答辩。')
];

// 根据 id 查找任务
export function findTaskById(id: number): TaskInfo | null {
  for (let i = 0; i < TASKS.length; i++) {
    if (TASKS[i].id === id) {
      return TASKS[i];
    }
  }
  return null;
}

// 状态对应的标签颜色
export function statusColor(status: string): string {
  if (status === '已完成') {
    return '#34B369';
  } else if (status === '进行中') {
    return '#F5A623';
  }
  return '#999999';
}
