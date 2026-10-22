/**
 * LrcParser.ets —— LRC 歌词解析与字级同步计算
 *
 * LRC 行格式：[mm:ss.xx]歌词文本
 * 字级同步策略：当前行的每个字按“本行时长 / 字数”平均分配，
 * 根据播放进度计算已演唱到第几个字，图标在该字上弹跳。
 */

export class LrcLine {
  timeMs: number;
  text: string;

  constructor(timeMs: number, text: string) {
    this.timeMs = timeMs;
    this.text = text;
  }
}

/** 解析完整 LRC 文本，返回按时间升序排列的歌词行 */
export function parseLrc(content: string): LrcLine[] {
  const result: LrcLine[] = [];
  const lines: string[] = content.split(/\r?\n/);
  const tagReg: RegExp = /\[(\d{1,2}):(\d{1,2})(?:[.:](\d{1,3}))?\]/g;
  for (let i = 0; i < lines.length; i++) {
    const line: string = lines[i].trim();
    if (line.length === 0) {
      continue;
    }
    tagReg.lastIndex = 0;
    let match: RegExpExecArray | null = tagReg.exec(line);
    if (match === null) {
      continue;
    }
    // 一行可能带多个时间标签，取行尾最后一个标签之后的文本作为歌词
    let lastEnd: number = 0;
    while (match !== null) {
      lastEnd = match.index + match[0].length;
      const min: number = parseInt(match[1], 10);
      const sec: number = parseInt(match[2], 10);
      const fracStr: string = match[3] ?? '0';
      const frac: number = fracStr.length === 3 ? parseInt(fracStr, 10)
                        : fracStr.length === 2 ? parseInt(fracStr, 10) * 10
                        : parseInt(fracStr, 10) * 100;
      const t: number = min * 60000 + sec * 1000 + frac;
      const next: RegExpExecArray | null = tagReg.exec(line);
      const textEnd: number = next !== null ? next.index : line.length;
      const text: string = line.substring(lastEnd, textEnd).trim();
      if (text.length > 0) {
        result.push(new LrcLine(t, text));
      }
      match = next;
    }
  }
  result.sort((a: LrcLine, b: LrcLine): number => a.timeMs - b.timeMs);
  return result;
}

/** 找到当前播放时间对应的歌词行序号，无匹配返回 -1 */
export function findActiveLine(lines: LrcLine[], timeMs: number): number {
  let idx: number = -1;
  for (let i = 0; i < lines.length; i++) {
    if (lines[i].timeMs <= timeMs) {
      idx = i;
    } else {
      break;
    }
  }
  return idx;
}

/**
 * 计算当前行已经唱到第几个字（0-based）。
 * 行时长 = 下一行开始时间 - 本行开始时间；最后一行给 6 秒默认时长。
 */
export function findActiveChar(lines: LrcLine[], lineIdx: number, timeMs: number): number {
  if (lineIdx < 0 || lineIdx >= lines.length) {
    return -1;
  }
  const cur: LrcLine = lines[lineIdx];
  const nextStart: number = lineIdx + 1 < lines.length ? lines[lineIdx + 1].timeMs : cur.timeMs + 6000;
  const span: number = Math.max(nextStart - cur.timeMs, 1);
  const ratio: number = (timeMs - cur.timeMs) / span;
  const count: number = cur.text.length;
  let charIdx: number = Math.floor(ratio * count);
  if (charIdx < 0) {
    charIdx = 0;
  }
  if (charIdx > count - 1) {
    charIdx = count - 1;
  }
  return charIdx;
}
