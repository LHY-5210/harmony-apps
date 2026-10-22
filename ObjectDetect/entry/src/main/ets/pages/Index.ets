import { CapturePage } from './CapturePage';
import { HistoryPage } from './HistoryPage';
import { CloudPage } from './CloudPage';

@Entry
@Component
struct Index {
  @State currentTab: number = 0;
  @State historyTick: number = 0;
  @State cloudTick: number = 0;

  @Builder
  tabButton(title: string, index: number) {
    Column({ space: 2 }) {
      Text(title)
        .fontSize(14)
        .fontColor(this.currentTab === index ? '#2f6bff' : '#888')
    }
    .width('100%')
    .height(48)
    .justifyContent(FlexAlign.Center)
  }

  build() {
    Tabs({ barPosition: BarPosition.End }) {
      TabContent() {
        CapturePage()
      }
      .tabBar(this.tabButton('识别', 0))

      TabContent() {
        HistoryPage({ tick: this.historyTick })
      }
      .tabBar(this.tabButton('历史', 1))

      TabContent() {
        CloudPage({ tick: this.cloudTick })
      }
      .tabBar(this.tabButton('云端', 2))
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#10142a')
    .barBackgroundColor('#1a1f35')
    .onChange((i: number) => {
      this.currentTab = i;
      if (i === 1) {
        this.historyTick = this.historyTick + 1;
      }
      if (i === 2) {
        this.cloudTick = this.cloudTick + 1;
      }
    })
  }
}
