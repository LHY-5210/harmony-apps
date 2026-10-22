// 语音播报服务：封装 HarmonyOS CoreSpeechKit 的语音合成（TTS）
// 单例模式，全应用共享一个引擎实例；引擎不可用时静默降级，不影响计算器正常使用
import { textToSpeech } from '@kit.CoreSpeechKit';

export class SpeechService {
  private static instance: SpeechService | null = null;
  private engine: textToSpeech.TextToSpeechEngine | null = null;
  private ready: boolean = false;
  private initializing: boolean = false;
  private requestSeq: number = 0;

  // 获取单例
  static getInstance(): SpeechService {
    if (SpeechService.instance === null) {
      SpeechService.instance = new SpeechService();
    }
    return SpeechService.instance;
  }

  // 初始化 TTS 引擎（幂等，可重复调用）
  async init(): Promise<void> {
    if (this.ready || this.initializing) {
      return;
    }
    this.initializing = true;
    try {
      const extraParam: Record<string, Object> = {
        'style': 'interaction', // 交互风格，播报简短清晰
        'locate': 'CN',
        'name': 'Chinese'
      };
      const initParams: textToSpeech.CreateEngineParams = {
        'language': 'zh-CN',
        'person': 1,
        'online': 1, // 优先在线合成，设备不支持时由系统自动回退
        'extraParams': extraParam
      };
      this.engine = await textToSpeech.createEngine(initParams);
      // 先注册监听器，再播报，才能收到完整的合成/播放事件
      this.engine.setListener(this.createListener());
      this.ready = true;
    } catch (err) {
      // 引擎创建失败（如设备不支持 TTS）时静默降级，不影响计算功能
      this.ready = false;
      this.engine = null;
    } finally {
      this.initializing = false;
    }
  }

  // 朗读一段文本
  speak(text: string): void {
    if (!this.ready || this.engine === null || text.length === 0) {
      return;
    }
    try {
      this.requestSeq += 1;
      const speakParam: textToSpeech.SpeakParams = {
        'requestId': 'calc_tts_' + this.requestSeq.toString(),
        'extraParams': {
          'speed': 1,      // 正常语速
          'volume': 1,     // 最大音量
          'pitch': 1,      // 正常音调
          'languageContext': 'CN',
          'audioType': 'pcm',
          'soundChannel': 3,
          'playType': 1
        }
      };
      this.engine.speak(text, speakParam);
    } catch (err) {
      // 单次播报失败不影响后续使用
    }
  }

  // 释放引擎（页面销毁时调用）
  shutdown(): void {
    if (this.engine !== null) {
      try {
        this.engine.shutdown();
      } catch (err) {
        // 忽略释放异常
      }
    }
    this.engine = null;
    this.ready = false;
  }

  private createListener(): textToSpeech.SpeakListener {
    const listener: textToSpeech.SpeakListener = {
      onStart: (requestId: string, response: textToSpeech.StartResponse): void => {
      },
      onComplete: (requestId: string, response: textToSpeech.CompleteResponse): void => {
      },
      onStop: (requestId: string, response: textToSpeech.StopResponse): void => {
      },
      onError: (requestId: string, errorCode: number, errorMessage: string): void => {
      }
    };
    return listener;
  }
}

// 把计算器按键映射为中文播报内容
export function keySpeechText(keyId: string): string {
  switch (keyId) {
    case 'dot':
      return '点';
    case 'add':
      return '加';
    case 'subtract':
      return '减';
    case 'multiply':
      return '乘以';
    case 'divide':
      return '除以';
    case 'equals':
      return '等于';
    case 'clear':
      return '清除';
    case 'backspace':
      return '删除';
    case 'negate':
      return '正负号';
    case 'percent':
      return '百分号';
    default:
      // 数字键直接朗读数字本身
      return keyId;
  }
}
