/**
 * SpeechHelper.ets —— 语音点歌（鸿蒙 AI 开放能力：Speech Kit）
 *
 * 1. 动态申请麦克风权限
 * 2. speechRecognizer 离线短语音识别，把语音转成文本
 * 3. 关键词匹配解析指令：“播放《歌名》”“暂停”“下一首”“上一首”
 */
import { abilityAccessCtrl, common, Permissions } from '@kit.AbilityKit';
import { speechRecognizer } from '@kit.CoreSpeechKit';
import { Song, StoreKeys } from './Song';
import { PlayerManager } from './PlayerManager';

export class SpeechHelper {
  private static instance: SpeechHelper | null = null;
  private engine: speechRecognizer.SpeechRecognitionEngine | null = null;
  private sessionId: string = 'music-asr-001';

  private constructor() {
  }

  static getInstance(): SpeechHelper {
    if (SpeechHelper.instance === null) {
      SpeechHelper.instance = new SpeechHelper();
    }
    return SpeechHelper.instance;
  }

  /** 启动一次语音识别，识别结果自动解析并执行；tip 回调用于刷新界面提示 */
  async start(ctx: common.UIAbilityContext, tip: (s: string) => void): Promise<void> {
    try {
      // 1. 申请麦克风权限
      const perm: Permissions = 'ohos.permission.MICROPHONE';
      const atManager: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager();
      const res = await atManager.requestPermissionsFromUser(ctx, [perm]);
      if (res.authResults.length === 0 || res.authResults[0] !== 0) {
        tip('未获得麦克风权限，无法语音点歌');
        return;
      }

      // 2. 创建识别引擎（离线中文短语音）
      if (this.engine === null) {
        this.engine = await speechRecognizer.createEngine({
          language: 'zh-CN',
          online: 1
        });
        this.engine.setListener({
          onStart: (sessionId: string, eventMessage: string): void => {
            tip('正在聆听…请说出指令');
          },
          onEvent: (sessionId: string, eventCode: number, eventMessage: string): void => {
            if (eventCode === 3) {
              tip('识别结束');
            }
          },
          onResult: (sessionId: string, result: speechRecognizer.SpeechRecognitionResult): void => {
            if (result.isFinal && result.result.length > 0) {
              const feedback: string = this.executeCommand(result.result);
              tip(`听到：“${result.result}”  →  ${feedback}`);
            }
          },
          onComplete: (sessionId: string, eventMessage: string): void => {
          },
          onError: (sessionId: string, errorCode: number, errorMessage: string): void => {
            tip(`语音识别出错（${errorCode}）`);
          }
        });
      }

      // 3. 开始监听（16kHz / 16bit / 单声道 PCM）
      const params: speechRecognizer.StartParams = {
        sessionId: this.sessionId,
        audioInfo: {
          audioType: 'pcm',
          sampleRate: 16000,
          soundChannel: 1,
          sampleBit: 16
        },
        extraParams: {
          // 识别完成后自动断句，便于立即拿到最终结果
          ONESHOT: 1,
          VAD_END: 1500
        }
      };
      this.engine.startListening(params);
    } catch (e) {
      tip('当前设备不支持语音识别，请用按键控制');
    }
  }

  /** 关键词匹配解析指令，返回执行结果提示语 */
  private executeCommand(raw: string): string {
    const pm: PlayerManager = PlayerManager.getInstance();
    let text: string = raw.replace(/[\s，。、,.!?！？《》<>]/g, '');
    if (text.includes('暂停')) {
      pm.pausePlay();
      return '已暂停';
    }
    if (text.includes('上一首')) {
      pm.prev();
      return '切换到上一首';
    }
    if (text.includes('下一首')) {
      pm.next();
      return '切换到下一首';
    }
    if (text.includes('继续') || (text.includes('播放') && text.length <= 3)) {
      pm.resumePlay();
      return '继续播放';
    }
    if (text.includes('播放')) {
      const keyword: string = text.replace(/播放|歌曲|音乐|一首|一下|我想听|来首/g, '');
      const all: Song[] = AppStorage.get<Song[]>(StoreKeys.ALL_SONGS) ?? [];
      for (let i = 0; i < all.length; i++) {
        if (all[i].title.includes(keyword) || all[i].artist.includes(keyword)) {
          pm.setQueueAndPlay(all, i);
          return `正在播放《${all[i].title}》`;
        }
      }
      return `曲库中没有找到“${keyword}”`;
    }
    return '支持的指令：播放歌名 / 暂停 / 下一首 / 上一首';
  }
}
