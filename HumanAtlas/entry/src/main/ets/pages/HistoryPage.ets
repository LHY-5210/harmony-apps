import { promptAction } from '@kit.ArkUI';
import { FavoriteStore, HistoryItem } from '../model/FavoriteStore';

@Component
export struct HistoryPage {
  @State list: HistoryItem[] = [];
  @Prop @Watch('onReload') reloadTick: number = 0;

  aboutToAppear(): void {
    this.refresh();
  }

  onReload(): void {
    this.refresh();
  }

  private async refresh(): Promise<void> {
    try {
      this.list = await FavoriteStore.getInstance().getHistory();
    } catch (e) {}
  }

  private async clear(): Promise<void> {
    await FavoriteStore.getInstance().clearHistory();
    this.refresh();
    promptAction.showToast({ message: '历史已清空' });
  }

  private fmtTime(ts: number): string {
    const d = new Date(ts);
    const pad = (n: number) => n < 10 ? '0' + n : '' + n;
    return `${d.getMonth() + 1}/${d.getDate()} ${pad(d.getHours())}:${pad(d.getMinutes())}`;
  }

  build() {
    Column() {
      Row() {
        Text('浏览历史')
          .fontSize(22).fontWeight(FontWeight.Bold).fontColor(Color.White)
        Blank()
        if (this.list.length > 0) {
          Button('清空')
            .height(28).fontSize(12)
            .backgroundColor(Color.Transparent).fontColor('#ff8899')
            .onClick(() => { this.clear(); })
        }
      }
      .width('100%').padding({ left: 18, right: 18, top: 16, bottom: 10 })

      if (this.list.length === 0) {
        Column() {
          Text('⌛').fontSize(48).fontColor('#444')
          Text('还没有浏览记录')
            .fontSize(14).fontColor('#888').margin({ top: 12 })
        }
        .width('100%').layoutWeight(1)
        .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
      } else {
        List() {
          ForEach(this.list, (item: HistoryItem) => {
            ListItem() {
              Row() {
                Column({ space: 2 }) {
                  Text(item.name)
                    .fontSize(16).fontWeight(FontWeight.Medium)
                    .fontColor(Color.White).maxLines(1)
                  Text(this.fmtTime(item.visitTime))
                    .fontSize(11).fontColor('#888')
                }
                .layoutWeight(1).alignItems(HorizontalAlign.Start)
              }
              .width('100%').padding(14)
              .backgroundColor('#1e2440').borderRadius(10)
            }
          }, (item: HistoryItem) => item.structureId)
        }
        .width('100%').layoutWeight(1).padding({ left: 14, right: 14 })
      }
    }
    .width('100%').height('100%').backgroundColor('#0f1222')
  }
}
