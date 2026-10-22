// 有声计算器页面：标准四则运算，按键与结果实时语音播报
// 结构：UI 页面只负责交互与渲染，计算逻辑在 CalculatorEngine，语音在 SpeechService
import { router } from '@kit.ArkUI';
import { CalculatorEngine, Operator } from '../model/CalculatorEngine';
import { SpeechService, keySpeechText } from '../model/SpeechService';

// 按键类型
const KIND_NUMBER: string = 'number';       // 数字键
const KIND_FUNCTION: string = 'function';   // 功能键（C / 删除 / % / ±）
const KIND_OPERATOR: string = 'operator';   // 运算符键
const KIND_EQUALS: string = 'equals';       // 等号键

// 按键定义
class KeyDef {
  id: string;
  label: string;
  kind: string;

  constructor(id: string, label: string, kind: string) {
    this.id = id;
    this.label = label;
    this.kind = kind;
  }
}

@Entry
@Component
struct CalculatorPage {
  // 计算引擎与语音服务（UI 不持有任何计算规则）
  private engine: CalculatorEngine = new CalculatorEngine();
  private speech: SpeechService = SpeechService.getInstance();

  @State display: string = '0';
  @State expression: string = '';
  @State voiceOn: boolean = true;

  // 5 行 × 4 列键位布局
  private keyRows: KeyDef[][] = [
    [
      new KeyDef('clear', 'C', KIND_FUNCTION),
      new KeyDef('negate', '±', KIND_FUNCTION),
      new KeyDef('percent', '%', KIND_FUNCTION),
      new KeyDef('divide', '÷', KIND_OPERATOR)
    ],
    [
      new KeyDef('7', '7', KIND_NUMBER),
      new KeyDef('8', '8', KIND_NUMBER),
      new KeyDef('9', '9', KIND_NUMBER),
      new KeyDef('multiply', '×', KIND_OPERATOR)
    ],
    [
      new KeyDef('4', '4', KIND_NUMBER),
      new KeyDef('5', '5', KIND_NUMBER),
      new KeyDef('6', '6', KIND_NUMBER),
      new KeyDef('subtract', '−', KIND_OPERATOR)
    ],
    [
      new KeyDef('1', '1', KIND_NUMBER),
      new KeyDef('2', '2', KIND_NUMBER),
      new KeyDef('3', '3', KIND_NUMBER),
      new KeyDef('add', '+', KIND_OPERATOR)
    ],
    [
      new KeyDef('backspace', '⌫', KIND_FUNCTION),
      new KeyDef('0', '0', KIND_NUMBER),
      new KeyDef('dot', '.', KIND_NUMBER),
      new KeyDef('equals', '=', KIND_EQUALS)
    ]
  ];

  aboutToAppear(): void {
    // 预热语音引擎
    void this.speech.init();
  }

  // 统一的按键处理入口：驱动引擎 -> 同步显示 -> 语音播报
  private onKey(key: KeyDef): void {
    switch (key.id) {
      case 'clear':
        this.engine.clearAll();
        break;
      case 'backspace':
        this.engine.backspace();
        break;
      case 'negate':
        this.engine.toggleSign();
        break;
      case 'percent':
        this.engine.percent();
        break;
      case 'add':
        this.engine.inputOperator('+' as Operator);
        break;
      case 'subtract':
        this.engine.inputOperator('-' as Operator);
        break;
      case 'multiply':
        this.engine.inputOperator('×' as Operator);
        break;
      case 'divide':
        this.engine.inputOperator('÷' as Operator);
        break;
      case 'equals':
        this.engine.equals();
        break;
      case 'dot':
        this.engine.inputDot();
        break;
      default:
        // 0-9 数字键
        this.engine.inputDigit(key.label);
        break;
    }

    // 同步引擎状态到 UI
    this.display = this.engine.display;
    this.expression = this.engine.expression;

    // 语音播报
    if (this.voiceOn) {
      if (key.id === 'equals') {
        if (this.engine.hasError) {
          this.speech.speak('错误，不能除以零');
        } else {
          this.speech.speak('等于 ' + this.engine.display);
        }
      } else {
        this.speech.speak(keySpeechText(key.id));
      }
    }
  }

  // 判断运算符是否处于"待执行"高亮状态
  private isOperatorActive(key: KeyDef): boolean {
    return key.kind === KIND_OPERATOR &&
      this.expression.length > 0 &&
      this.expression.charAt(this.expression.length - 1) === this.engineSymbol(key.id);
  }

  // 键位 id 转引擎中的运算符符号（用于表达式匹配）
  private engineSymbol(id: string): string {
    if (id === 'subtract') {
      return '-';
    }
    if (id === 'multiply') {
      return '×';
    }
    if (id === 'divide') {
      return '÷';
    }
    return '+';
  }

  build() {
    Column() {
      // 顶部标题栏
      Row({ space: 12 }) {
        Text('‹').fontSize(26).fontColor('#FFFFFF')
          .onClick(() => {
            router.back();
          })
        Text('有声计算器').fontSize(18).fontWeight(FontWeight.Medium).fontColor('#FFFFFF')
        Blank()
        Text(this.voiceOn ? '🔊' : '🔇').fontSize(20)
          .width(40).height(40).textAlign(TextAlign.Center)
          .onClick(() => {
            this.voiceOn = !this.voiceOn;
            if (this.voiceOn) {
              void this.speech.init();
              this.speech.speak('语音已开启');
            }
          })
      }
      .width('100%').height(56).padding({ left: 14, right: 8 })
      .backgroundColor('#3D7EF7')

      // 显示区
      Column() {
        Text(this.expression)
          .width('100%').textAlign(TextAlign.End)
          .fontSize(18).fontColor('#999999').maxLines(1)
          .height(28)
        Text(this.display)
          .width('100%').textAlign(TextAlign.End)
          .fontSize(this.display.length > 9 ? 38 : 54)
          .fontWeight(FontWeight.Bold).fontColor('#1A1A1A').maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%').layoutWeight(1)
      .padding({ left: 20, right: 20, top: 16, bottom: 16 })
      .justifyContent(FlexAlign.End)

      // 键盘区：5 行等高分布
      Column({ space: 10 }) {
        ForEach(this.keyRows, (row: KeyDef[]) => {
          Row({ space: 10 }) {
            ForEach(row, (key: KeyDef) => {
              this.keyButton(key)
            }, (key: KeyDef) => key.id)
          }
          .layoutWeight(1).width('100%')
        }, (row: KeyDef[], rowIndex: number) => rowIndex.toString())
      }
      .width('100%').padding({ left: 12, right: 12, top: 4, bottom: 20 })
      .layoutWeight(2)
    }
    .width('100%').height('100%').backgroundColor('#F2F3F5')
  }

  // 单个按键（按类型着色，专业计算器风格）
  @Builder
  keyButton(key: KeyDef) {
    Button(key.label)
      .layoutWeight(1).height('100%')
      .fontSize(key.label.length > 1 ? 22 : 28)
      .fontWeight(key.kind === KIND_NUMBER ? FontWeight.Normal : FontWeight.Medium)
      .fontColor(this.keyTextColor(key))
      .backgroundColor(this.keyBackgroundColor(key))
      .borderRadius(12)
      .onClick(() => {
        this.onKey(key);
      })
  }

  private keyTextColor(key: KeyDef): ResourceColor {
    if (key.kind === KIND_EQUALS) {
      return '#FFFFFF';
    }
    if (key.kind === KIND_OPERATOR) {
      return this.isOperatorActive(key) ? '#FFFFFF' : '#FF9500';
    }
    return '#1A1A1A';
  }

  private keyBackgroundColor(key: KeyDef): ResourceColor {
    if (key.kind === KIND_EQUALS) {
      return '#FF9500';
    }
    if (key.kind === KIND_OPERATOR) {
      return this.isOperatorActive(key) ? '#FF9500' : '#FFFFFF';
    }
    if (key.kind === KIND_FUNCTION) {
      return '#DCE0E8';
    }
    return '#FFFFFF';
  }
}
