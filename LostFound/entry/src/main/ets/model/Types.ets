// 数据模型定义
export type ItemType = 'lost' | 'found';
export type UserRole = 'user' | 'admin';

export class User {
  id: number = 0;
  username: string = '';
  role: UserRole = 'user';
  creditScore: number = 100;
  banClaimCount: number = 0;
}

export class Item {
  itemId: string = '';
  userId: number = 0;
  type: ItemType = 'lost';
  category: string = '';
  color: string = '';
  location: string = '';
  eventTime: number = 0;
  description: string = '';
  ocrText: string = '';
  imageUrl: string = '';
  credentialQuestion: string = '';
  credentialAnswer: string = '';
  status: string = '待匹配';
  createdAt: number = 0;
}

export class Candidate {
  itemId: string = '';
  score: number = 0;
  factors: Record<string, number> = {};
}

export class MatchPair {
  id: number = 0;
  lostItemId: string = '';
  foundItemId: string = '';
  score: number = 0;
  factors: Record<string, number> = {};
  status: string = '待确认';
  winnerClaimId: number = 0;
  createdAt: number = 0;
  expiresAt: number = 0;
}

export class TimelineEvent {
  id: number = 0;
  matchId: number = 0;
  itemId: string = '';
  event: string = '';
  actorId: number = 0;
  createdAt: number = 0;
}

export class Appeal {
  id: number = 0;
  matchId: number = 0;
  appellantId: number = 0;
  evidenceLevel: number = 1;
  evidenceText: string = '';
  status: string = '待裁定';
  createdAt: number = 0;
}

export class CreditLog {
  id: number = 0;
  userId: number = 0;
  delta: number = 0;
  reason: string = '';
  createdAt: number = 0;
}

export interface CreditInfo {
  creditScore: number;
  banClaimCount: number;
  logs: CreditLog[];
}

// 凭证证据等级
export const EVIDENCE_LEVELS: string[] = ['L1 凭证作答记录', 'L2 OCR 线索比对', 'L3 证件 OCR 识别'];

// 物品类别池（与 AI 分类对应）
export const CATEGORIES: string[] = ['校园卡', '钥匙', '书本', '水杯', '钱包', '雨伞', '耳机', '手机', '证件', '背包'];

// 颜色池
export const COLORS: string[] = ['黑色', '白色', '红色', '蓝色', '绿色', '黄色', '灰色'];
