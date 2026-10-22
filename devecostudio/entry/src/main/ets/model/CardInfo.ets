// 名片数据模型与公共工具

// 名片实体类
export class CardInfo {
  id: number = 0;
  name: string = '';        // 姓名（必填）
  company: string = '';     // 公司/单位
  title: string = '';       // 职位
  phone: string = '';       // 电话（必填）
  email: string = '';       // 邮箱
  address: string = '';     // 地址
  groupName: string = '其他'; // 分组
  favorite: number = 0;     // 1=收藏 0=未收藏
  note: string = '';        // 备注
  createTime: number = 0;   // 创建时间戳
}

// 路由参数类型
export interface DetailParams {
  id: number;
}

export interface EditParams {
  mode: string;             // 'add' | 'edit'
  card: CardInfo | null;    // 编辑时传原名片；导入预填时传解析结果；新增传 null
}

// 分组常量
export const GROUPS: string[] = ['同学', '同事', '客户', '朋友', '家人', '其他'];

// 头像底色（按姓名哈希取色，实现"每个人头像颜色固定"）
const AVATAR_COLORS: string[] =
  ['#3D7EF7', '#34B369', '#F5A623', '#E64545', '#8E5CD9', '#00A6A6', '#E8638C', '#5B8FF9'];

export function avatarColor(name: string): string {
  let sum: number = 0;
  for (let i = 0; i < name.length; i++) {
    sum += name.charCodeAt(i);
  }
  return AVATAR_COLORS[sum % AVATAR_COLORS.length];
}

// 名片 -> vCard 标准文本（用于二维码展示与复制分享）
export function toVCard(c: CardInfo): string {
  let s: string = 'BEGIN:VCARD\nVERSION:3.0\n';
  s += 'FN:' + c.name + '\n';
  s += 'ORG:' + c.company + '\n';
  s += 'TITLE:' + c.title + '\n';
  s += 'TEL:' + c.phone + '\n';
  s += 'EMAIL:' + c.email + '\n';
  s += 'ADR:' + c.address + '\n';
  s += 'NOTE:' + c.note + '\n';
  s += 'END:VCARD';
  return s;
}

// vCard 文本 -> 名片（用于剪贴板导入）
export function parseVCard(text: string): CardInfo {
  const c = new CardInfo();
  const lines: string[] = text.split('\n');
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i].trim();
    if (line.startsWith('FN:')) {
      c.name = line.substring(3);
    } else if (line.startsWith('ORG:')) {
      c.company = line.substring(4);
    } else if (line.startsWith('TITLE:')) {
      c.title = line.substring(6);
    } else if (line.startsWith('TEL:')) {
      c.phone = line.substring(4);
    } else if (line.startsWith('EMAIL:')) {
      c.email = line.substring(6);
    } else if (line.startsWith('ADR:')) {
      c.address = line.substring(4);
    } else if (line.startsWith('NOTE:')) {
      c.note = line.substring(5);
    }
  }
  return c;
}

// 时间戳 -> 'YYYY-MM-DD HH:mm'
export function fmtTime(t: number): string {
  const d = new Date(t);
  const p = (n: number): string => (n < 10 ? '0' + n : '' + n);
  return d.getFullYear() + '-' + p(d.getMonth() + 1) + '-' + p(d.getDate())
    + ' ' + p(d.getHours()) + ':' + p(d.getMinutes());
}