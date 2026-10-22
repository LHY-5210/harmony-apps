/**
 * PlayerPage.ets —— 播放主页
 * 旋转封面、歌曲信息、字级歌词、进度拖动、播放控制、音量、语音点歌入口
 */
import { common } from '@kit.AbilityKit';
import { Song, PlayMode } from '../model/Song';
import { LrcLine } from '../model/LrcParser';
import { PlayerManager } from '../model/PlayerManager';
import { SpeechHelper } from '../model/SpeechHelper';
import { Theme, formatTime } from '../common/Theme';
import { CoverImage } from '../components/CoverImage';
import { LyricView } from '../components/LyricView';

@Component
export struct PlayerPage {
  @StorageLink('curSong') curSong: Song | null = null;
  @StorageLink('isPlaying') isPlaying: boolean = false;
  @StorageLink('position') posMs: number = 0;
  @StorageLink('duration') duration: number = 0;
  @StorageLink('volume') volume: number = 1;
  @StorageLink('playMode') playMode: number = PlayMode.LIST;
  @StorageLink('lrcLines') lrcLines: LrcLine[] = [];
  @StorageLink('voiceTip') voiceTip: string = '点击右侧“语音点歌”，说出：播放歌名 / 暂停 / 下一首';
  @State dragging: boolean = false;
  @State dragPos: number = 0;

  private displayPos(): number {
    return this.dragging ? this.dragPos : this.posMs;
  }

  private modeText(): string {
    if (this.playMode === PlayMode.RANDOM) {
      return '⇄ 随机';
    }
    if (this.playMode === PlayMode.SINGLE) {
      return '↻ 单曲';
    }
    return '↦ 顺序';
  }

  build() {
    Column() {
      // 顶部语音条
      Row({ space: 10 }) {
        Text(this.voiceTip)
          .fontSize(12)
          .fontColor(Theme.MUTED)
          .layoutWeight(1)
          .maxLines(2)
        Button('语音点歌')
          .height(34)
          .fontSize(13)
          .fontColor('#201633')
          .backgroundColor(Theme.GOLD)
          .onClick(() => {
            const ctx: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
            SpeechHelper.getInstance().start(ctx, (s: string) => {
              this.voiceTip = s;
            });
          })
      }
      .width('100%')
      .padding({ left: 18, right: 18, top: 14 })

      // 旋转封面
      Stack() {
        CoverImage({ song: this.curSong, imgSize: 216, round: true })
          .rotate({ angle: this.displayPos() / 1000 * 36 })
          .animation({
            duration: 1000,
            curve: Curve.Linear,
            iterations: 1
          })
      }
      .margin({ top: 10 })
      .width(232)
      .height(232)
      .borderRadius(116)
      .backgroundColor('#2A2150')
      .alignContent(Alignment.Center)

      // 歌曲信息
      Column({ space: 5 }) {
        Text(this.curSong === null ? '未在播放' : this.curSong.title)
          .fontSize(21)
          .fontWeight(FontWeight.Bold)
          .fontColor(Theme.TEXT)
          .maxLines(1)
        Text(this.curSong === null ? '去音乐库选一首歌吧' : `${this.curSong.artist} · ${this.curSong.album}`)
          .fontSize(13)
          .fontColor(Theme.MUTED)
          .maxLines(1)
      }
      .margin({ top: 14 })

      // 字级歌词
      LyricView({ lines: this.lrcLines })

      // 进度条
      Row({ space: 8 }) {
        Text(formatTime(this.displayPos()))
          .fontSize(11)
          .fontColor(Theme.MUTED)
          .width(38)
        Slider({
          max: this.duration > 0 ? this.duration : 1,
          value: this.dragging ? this.dragPos : this.posMs,
          step: 1000
        })
          .layoutWeight(1)
          .selectedColor(Theme.GOLD)
          .trackColor('#463C68')
          .blockColor(Theme.TEXT)
          .trackThickness(3)
          .onChange((value: number, mode: SliderChangeMode) => {
            if (mode === SliderChangeMode.Moving) {
              this.dragging = true;
              this.dragPos = value;
            } else {
              PlayerManager.getInstance().seekTo(value);
              this.dragging = false;
            }
          })
        Text(formatTime(this.duration))
          .fontSize(11)
          .fontColor(Theme.MUTED)
          .width(38)
      }
      .width('100%')
      .padding({ left: 18, right: 18 })
      .margin({ top: 2 })

      // 控制按钮
      Row() {
        Button(this.modeText())
          .height(34)
          .fontSize(12)
          .fontColor(Theme.MUTED)
          .backgroundColor(Theme.CARD)
          .onClick(() => {
            PlayerManager.getInstance().cycleMode();
          })
        Blank()
        Button('❮')
          .fontSize(26)
          .fontColor(Theme.TEXT)
          .backgroundColor(Color.Transparent)
          .height(56)
          .width(56)
          .onClick(() => {
            PlayerManager.getInstance().prev();
          })
        Stack() {
          Text(this.isPlaying ? 'Ⅱ' : '▶')
            .fontSize(26)
            .fontColor('#201633')
        }
        .width(64)
        .height(64)
        .borderRadius(32)
        .backgroundColor(Theme.GOLD)
        .alignContent(Alignment.Center)
        .margin({ left: 18, right: 18 })
        .onClick(() => {
          PlayerManager.getInstance().togglePlay();
        })
        Button('❯')
          .fontSize(26)
          .fontColor(Theme.TEXT)
          .backgroundColor(Color.Transparent)
          .height(56)
          .width(56)
          .onClick(() => {
            PlayerManager.getInstance().next();
          })
        Blank()
        Text('')
          .width(64)
          .height(1)
      }
      .width('100%')
      .padding({ left: 18, right: 18 })
      .margin({ top: 4 })

      // 音量
      Row({ space: 8 }) {
        Text('音量')
          .fontSize(12)
          .fontColor(Theme.MUTED)
        Slider({ max: 1, value: this.volume, step: 0.05 })
          .layoutWeight(1)
          .selectedColor(Theme.ACCENT)
          .trackColor('#463C68')
          .blockColor(Theme.TEXT)
          .trackThickness(3)
          .onChange((value: number) => {
            this.volume = value;
            PlayerManager.getInstance().setVolume(value);
          })
      }
      .width('100%')
      .padding({ left: 18, right: 18, top: 6 })
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Center)
  }
}
