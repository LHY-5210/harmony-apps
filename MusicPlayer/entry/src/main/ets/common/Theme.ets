/**
 * Theme.ets —— 全局视觉常量与工具函数
 */

export class Theme {
  static readonly BG_TOP: string = '#1E1438';
  static readonly BG_BOTTOM: string = '#0D0D16';
  static readonly CARD: string = '#241D3F';
  static readonly CARD_2: string = '#2E2550';
  static readonly GOLD: string = '#E8B45A';
  static readonly ACCENT: string = '#8E7BFF';
  static readonly TEXT: string = '#F4F1FA';
  static readonly MUTED: string = '#A79FC0';
  static readonly DANGER: string = '#E06C6C';
}

/** 毫秒 → m:ss */
export function formatTime(ms: number): string {
  if (!Number.isFinite(ms) || ms < 0) {
    return '0:00';
  }
  const total: number = Math.floor(ms / 1000);
  const m: number = Math.floor(total / 60);
  const s: number = total % 60;
  return `${m}:${s < 10 ? '0' : ''}${s}`;
}
