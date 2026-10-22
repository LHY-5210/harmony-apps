// 计算器核心引擎：纯逻辑，不依赖任何 UI 组件，便于复用与测试
// 采用标准计算器状态机：累加器 + 待执行运算符 + 等待新输入标记

// 运算符（使用与界面一致的符号）
export type Operator = '+' | '-' | '×' | '÷';

const MAX_DIGITS: number = 12;       // 单个数最多输入 12 位数字
const ERROR_TEXT: string = '错误';

export class CalculatorEngine {
  // 供 UI 观察的状态
  display: string = '0';        // 当前显示内容
  expression: string = '';      // 表达式预览，如 "12 +" 或 "12 + 3 ="
  hasError: boolean = false;    // 是否处于错误状态（如除以 0）

  private accumulator: number = 0;   // 已暂存的左操作数
  private pendingOp: Operator | null = null; // 待执行的运算符
  private waitingForOperand: boolean = true;  // 下一次按数字是否开始新输入

  // 数字 0-9
  inputDigit(digit: string): void {
    if (this.hasError) {
      this.clearAll();
    }
    if (this.waitingForOperand) {
      this.display = digit;
      this.waitingForOperand = false;
    } else {
      if (this.countDigits() >= MAX_DIGITS) {
        return;
      }
      this.display = this.display === '0' ? digit : this.display + digit;
    }
  }

  // 小数点
  inputDot(): void {
    if (this.hasError) {
      this.clearAll();
    }
    if (this.waitingForOperand) {
      this.display = '0.';
      this.waitingForOperand = false;
      return;
    }
    if (!this.display.includes('.')) {
      this.display += '.';
    }
  }

  // 四则运算符（支持连续运算：输入 1 + 2 + 后即时得到 3 +）
  inputOperator(op: Operator): void {
    if (this.hasError) {
      return;
    }
    const current: number = parseFloat(this.display);
    if (this.pendingOp !== null && !this.waitingForOperand) {
      const result: number | null = this.compute(this.accumulator, current, this.pendingOp);
      if (result === null) {
        this.setError();
        return;
      }
      this.accumulator = result;
      this.display = formatNumber(result);
    } else {
      this.accumulator = current;
    }
    this.pendingOp = op;
    this.waitingForOperand = true;
    this.expression = formatNumber(this.accumulator) + ' ' + op;
  }

  // 等号：执行暂存的运算
  equals(): void {
    if (this.hasError || this.pendingOp === null) {
      return;
    }
    const current: number = parseFloat(this.display);
    const result: number | null = this.compute(this.accumulator, current, this.pendingOp);
    this.expression = formatNumber(this.accumulator) + ' ' + this.pendingOp + ' ' +
      formatNumber(current) + ' =';
    this.pendingOp = null;
    this.waitingForOperand = true;
    if (result === null) {
      this.setError();
      return;
    }
    this.display = formatNumber(result);
  }

  // 百分号：当前数值除以 100
  percent(): void {
    if (this.hasError) {
      return;
    }
    const value: number = parseFloat(this.display) / 100;
    this.display = formatNumber(value);
    this.waitingForOperand = true;
  }

  // 正负号切换
  toggleSign(): void {
    if (this.hasError || this.display === '0') {
      return;
    }
    if (this.display.startsWith('-')) {
      this.display = this.display.substring(1);
    } else {
      this.display = '-' + this.display;
    }
  }

  // 退格删除
  backspace(): void {
    if (this.hasError) {
      this.clearAll();
      return;
    }
    if (this.waitingForOperand) {
      return;
    }
    if (this.display.length <= 1 ||
      (this.display.length === 2 && this.display.startsWith('-'))) {
      this.display = '0';
      this.waitingForOperand = true;
      return;
    }
    this.display = this.display.substring(0, this.display.length - 1);
  }

  // 全部清除（C）
  clearAll(): void {
    this.display = '0';
    this.expression = '';
    this.hasError = false;
    this.accumulator = 0;
    this.pendingOp = null;
    this.waitingForOperand = true;
  }

  // 单次四则运算；除以 0 返回 null
  private compute(a: number, b: number, op: Operator): number | null {
    switch (op) {
      case '+':
        return a + b;
      case '-':
        return a - b;
      case '×':
        return a * b;
      case '÷':
        if (b === 0) {
          return null;
        }
        return a / b;
      default:
        return b;
    }
  }

  private setError(): void {
    this.hasError = true;
    this.display = ERROR_TEXT;
    this.expression = '';
    this.pendingOp = null;
    this.accumulator = 0;
    this.waitingForOperand = true;
  }

  private countDigits(): number {
    return this.display.replace('-', '').replace('.', '').length;
  }
}

// 数字格式化：消除浮点误差（如 0.1 + 0.2 = 0.30000000000000004）
export function formatNumber(value: number): string {
  if (!isFinite(value)) {
    return ERROR_TEXT;
  }
  // 保留 12 位有效数字后转回去掉多余的 0
  const rounded: number = parseFloat(value.toPrecision(12));
  return String(rounded);
}
