/**
 * Index.ets —— 应用主框架：底部四 Tab
 * 播放主页 / 音乐库 / 播放列表 / 我的歌单
 */
import { Theme } from '../common/Theme';
import { PlayerPage } from './PlayerPage';
import { LibraryPage } from './LibraryPage';
import { QueuePage } from './QueuePage';
import { PlaylistPage } from './PlaylistPage';

@Entry
@Component
struct Index {
  @State currentIndex: number = 0;

  @Builder
  tabBarItem(icon: string, label: string, index: number) {
    Column({ space: 3 }) {
      Text(icon)
        .fontSize(22)
        .fontColor(this.currentIndex === index ? Theme.GOLD : Theme.MUTED)
      Text(label)
        .fontSize(11)
        .fontColor(this.currentIndex === index ? Theme.GOLD : Theme.MUTED)
    }
    .width('100%')
    .height(56)
    .justifyContent(FlexAlign.Center)
  }

  build() {
    Tabs({ barPosition: BarPosition.End, index: this.currentIndex }) {
      TabContent() {
        PlayerPage()
      }
      .tabBar(this.tabBarItem('♫', '播放', 0))

      TabContent() {
        LibraryPage()
      }
      .tabBar(this.tabBarItem('♪', '音乐库', 1))

      TabContent() {
        QueuePage()
      }
      .tabBar(this.tabBarItem('≣', '列表', 2))

      TabContent() {
        PlaylistPage()
      }
      .tabBar(this.tabBarItem('♥', '歌单', 3))
    }
    .scrollable(false)
    .barMode(BarMode.Fixed)
    .barHeight(60)
    .barBackgroundColor('#161029')
    .onChange((index: number) => {
      this.currentIndex = index;
    })
    .linearGradient({
      angle: 180,
      colors: [[Theme.BG_TOP, 0.0], [Theme.BG_BOTTOM, 1.0]]
    })
  }
}
