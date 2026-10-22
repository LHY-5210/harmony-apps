/**
 * LyricView.ets —— 字级歌词同步组件
 *
 * 当前演唱行逐字高亮，音符图标在当前演唱的字上方弹跳；
 * 同时显示前后相邻行，营造卡拉 OK 效果。
 */
import { LrcLine, findActiveLine, findActiveChar } from '../model/LrcParser';
import { Theme } from '../common/Theme';

@Component
export struct LyricView {
  @Prop lines: LrcLine[] = [];
  @StorageLink('position') @Watch('onTick') timeMs: number = 0;
  @State bounceUp: boolean = false;

  onTick(): void {
    this.bounceUp = !this.bounceUp;
  }

  private activeLine(): number {
    return findActiveLine(this.lines, this.timeMs);
  }

  private activeChar(idx: number): number {
    return idx >= 0 ? findActiveChar(this.lines, idx, this.timeMs) : -1;
  }

  @Builder
  charLine(text: string, active: boolean, charIdx: number) {
    Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Center }) {
      ForEach(Array.from(text), (ch: string, idx: number) => {
        Stack({ alignContent: Alignment.Top }) {
          if (active && idx === charIdx) {
            Text('♪')
              .fontSize(13)
              .fontColor(Theme.GOLD)
              .margin({ top: -16 })
              .translate({ y: this.bounceUp ? -2 : 3 })
              .animation({ duration: 260, curve: Curve.EaseInOut })
          }
          Text(ch)
            .fontSize(active ? 19 : 15)
            .fontWeight(active ? FontWeight.Bold : FontWeight.Normal)
            .fontColor(active ? (idx <= charIdx ? Theme.GOLD : Theme.TEXT)
                              : Theme.MUTED)
            .margin({ left: 1, right: 1 })
        }
        .height(30)
      }, (ch: string, idx: number) => `${idx}-${ch}`)
    }
    .width('100%')
  }

  build() {
    Column() {
      if (this.lines.length === 0) {
        Text('♪ 暂无歌词，敬请欣赏旋律 ♪')
          .fontSize(15)
          .fontColor(Theme.MUTED)
          .margin({ top: 28 })
      } else {
        if (this.activeLine() > 0) {
          Text(this.lines[this.activeLine() - 1].text)
            .fontSize(13)
            .fontColor(Theme.MUTED)
            .maxLines(1)
            .opacity(0.65)
            .margin({ bottom: 6 })
        } else {
          Blank().height(4)
        }
        this.charLine(this.activeLine() >= 0 ? this.lines[this.activeLine()].text : this.lines[0].text,
                      this.activeLine() >= 0,
                      this.activeLine() >= 0 ? this.activeChar(this.activeLine()) : -1)
        if (this.activeLine() >= 0 && this.activeLine() + 1 < this.lines.length) {
          Text(this.lines[this.activeLine() + 1].text)
            .fontSize(13)
            .fontColor(Theme.MUTED)
            .maxLines(1)
            .opacity(0.65)
            .margin({ top: 6 })
        } else {
          Blank().height(4)
        }
      }
    }
    .width('90%')
    .height(108)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }
}
