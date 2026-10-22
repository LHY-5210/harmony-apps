/**
 * QueuePage.ets —— 播放列表页（当前播放队列）
 * 查看队列、点击切歌、移除单曲、清空队列
 */
import { Song } from '../model/Song';
import { PlayerManager } from '../model/PlayerManager';
import { Theme } from '../common/Theme';
import { CoverImage } from '../components/CoverImage';

@Component
export struct QueuePage {
  @StorageLink('queue') queue: Song[] = [];
  @StorageLink('queueIndex') queueIndex: number = -1;

  build() {
    Column() {
      Row() {
        Column() {
          Text('播放列表')
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor(Theme.TEXT)
          Text(`当前队列 ${this.queue.length} 首`)
            .fontSize(12)
            .fontColor(Theme.MUTED)
            .margin({ top: 2 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        if (this.queue.length > 0) {
          Button('清空')
            .height(34)
            .fontSize(13)
            .fontColor(Theme.DANGER)
            .backgroundColor(Theme.CARD)
            .onClick(() => {
              PlayerManager.getInstance().clearQueue();
            })
        }
      }
      .width('100%')
      .padding({ left: 18, right: 18, top: 16, bottom: 10 })

      if (this.queue.length === 0) {
        Column({ space: 10 }) {
          Text('♪')
            .fontSize(44)
            .fontColor(Theme.MUTED)
          Text('队列为空，去音乐库点一首歌吧')
            .fontSize(14)
            .fontColor(Theme.MUTED)
        }
        .layoutWeight(1)
        .width('100%')
        .justifyContent(FlexAlign.Center)
      } else {
        Scroll() {
          Column({ space: 8 }) {
            ForEach(this.queue, (song: Song, index: number) => {
              Row({ space: 12 }) {
                Text(`${index + 1}`)
                  .fontSize(13)
                  .fontColor(index === this.queueIndex ? Theme.GOLD : Theme.MUTED)
                  .width(22)
                CoverImage({ song: song, imgSize: 44, round: false })
                Column({ space: 3 }) {
                  Text(song.title)
                    .fontSize(15)
                    .fontWeight(index === this.queueIndex ? FontWeight.Bold : FontWeight.Normal)
                    .fontColor(index === this.queueIndex ? Theme.GOLD : Theme.TEXT)
                    .maxLines(1)
                  Text(song.artist)
                    .fontSize(12)
                    .fontColor(Theme.MUTED)
                    .maxLines(1)
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)

                if (index === this.queueIndex) {
                  Text('播放中')
                    .fontSize(10)
                    .fontColor(Theme.GOLD)
                    .margin({ right: 6 })
                }
                Button('×')
                  .width(28)
                  .height(28)
                  .fontSize(16)
                  .fontColor(Theme.MUTED)
                  .backgroundColor(Theme.CARD_2)
                  .onClick(() => {
                    PlayerManager.getInstance().removeFromQueue(index);
                  })
              }
              .width('100%')
              .padding(10)
              .backgroundColor(Theme.CARD)
              .borderRadius(12)
              .onClick(() => {
                PlayerManager.getInstance().jumpTo(index);
              })
            }, (song: Song, index: number) => `q-${index}-${song.key}`)
          }
          .width('92%')
          .padding({ bottom: 12 })
        }
        .layoutWeight(1)
        .align(Alignment.Top)
      }
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Center)
  }
}
