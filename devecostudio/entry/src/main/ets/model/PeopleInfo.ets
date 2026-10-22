// 人物数据模型：人物列表页使用
export class Person {
  id: number;
  name: string;
  role: string;
  detail: string;
  color: string;

  constructor(id: number, name: string, role: string, detail: string, color: string) {
    this.id = id;
    this.name = name;
    this.role = role;
    this.detail = detail;
    this.color = color;
  }
}

function makePerson(id: number, name: string, role: string, detail: string, color: string): Person {
  return new Person(id, name, role, detail, color);
}

// 示例人物数据：需要增加人物时按此格式在 PEOPLE 中追加
export const PEOPLE: Person[] = [
  makePerson(1, '李明', '项目负责人', '负责项目整体规划与进度管理，协调前后端资源，主导需求评审与方案设计，保障项目按期交付。', '#3D7EF7'),
  makePerson(2, '王芳', 'UI 设计师', '负责应用整体视觉风格与交互设计，输出高保真设计稿，制定颜色、字体与间距规范，保证界面风格一致。', '#34B369'),
  makePerson(3, '张伟', '鸿蒙开发工程师', '负责 ArkTS 页面开发与功能实现，熟悉 Stage 模型、ArkUI 声明式开发范式与常用系统 Kit 的集成。', '#FF9500'),
  makePerson(4, '刘洋', '测试工程师', '负责功能测试与兼容性测试，编写测试用例，跟踪缺陷修复，在真机与模拟器多环境下验证应用稳定性。', '#9B6DF7'),
  makePerson(5, '陈静', '产品经理', '负责需求分析与功能定义，梳理用户使用流程，输出原型与需求文档，平衡功能范围与开发成本。', '#E64545'),
  makePerson(6, '赵磊', '数据分析', '负责应用使用数据统计与分析，搭建数据看板，为功能迭代提供数据支持与决策建议。', '#00A8A8')
];
