import { FavoritesPage } from './FavoritesPage';
import { HistoryPage } from './HistoryPage';
import { AboutPage } from './AboutPage';
import { BrowserPage } from './BrowserPage';

@Entry
@Component
struct Index {
  @State currentIndex: number = 0;
  @State reloadTick: number = 0;

  build() {
    Tabs({ barPosition: BarPosition.End, index: this.currentIndex }) {
      TabContent() {
        BrowserPage()
      }
      .tabBar('解剖')

      TabContent() {
        FavoritesPage({ reloadTick: this.reloadTick })
      }
      .tabBar('收藏')

      TabContent() {
        HistoryPage({ reloadTick: this.reloadTick })
      }
      .tabBar('历史')

      TabContent() {
        AboutPage()
      }
      .tabBar('关于')
    }
    .scrollable(false)
    .barBackgroundColor('#1a1f35')
    .backgroundColor('#0f1222')
    .onChange((index: number) => {
      this.currentIndex = index;
      this.reloadTick++;
    })
  }
}
