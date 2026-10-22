import { promptAction } from '@kit.ArkUI';
import { FavoriteStore, FavoriteItem, NoteItem } from '../model/FavoriteStore';

@Component
export struct FavoritesPage {
  @State favs: FavoriteItem[] = [];
  @State notes: Map<string, NoteItem> = new Map();
  @Prop @Watch('onReload') reloadTick: number = 0;

  aboutToAppear(): void {
    this.refresh();
  }

  onReload(): void {
    this.refresh();
  }

  private async refresh(): Promise<void> {
    try {
      const list: FavoriteItem[] = await FavoriteStore.getInstance().getFavorites();
      this.favs = list;
      const map: Map<string, NoteItem> = new Map();
      for (let i = 0; i < list.length; i++) {
        const n: NoteItem | null = await FavoriteStore.getInstance().getNote(list[i].structureId);
        if (n !== null) { map.set(list[i].structureId, n); }
      }
      this.notes = map;
    } catch (e) {}
  }

  private async remove(item: FavoriteItem): Promise<void> {
    await FavoriteStore.getInstance().removeFavorite(item.structureId);
    promptAction.showToast({ message: `已移除 ${item.name}` });
    this.refresh();
  }

  build() {
    Column() {
      Row() {
        Text('我的收藏')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
        Blank()
        Text(`${this.favs.length} 项`)
          .fontSize(12)
          .fontColor('#888')
      }
      .width('100%')
      .padding({ left: 18, right: 18, top: 16, bottom: 10 })

      if (this.favs.length === 0) {
        Column() {
          Text('♥')
            .fontSize(48)
            .fontColor('#444')
          Text('还没有收藏的结构')
            .fontSize(14)
            .fontColor('#888')
            .margin({ top: 12 })
          Text('在"解剖"页点选结构后，回到此处点击 ♥ 收藏')
            .fontSize(11)
            .fontColor('#666')
            .margin({ top: 4 })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      } else {
        List() {
          ForEach(this.favs, (item: FavoriteItem) => {
            ListItem() {
              Row() {
                Column({ space: 2 }) {
                  Text(item.name)
                    .fontSize(16)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(Color.White)
                    .maxLines(1)
                  Text(item.system.length > 0 ? item.system : '未分类')
                    .fontSize(11)
                    .fontColor('#888')
                    .maxLines(1)
                  if (this.notes.has(item.structureId)) {
                    Text('📝 ' + (this.notes.get(item.structureId)?.title ?? ''))
                      .fontSize(10)
                      .fontColor('#56d4a7')
                      .maxLines(1)
                  }
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)

                Button('♡')
                  .width(32)
                  .height(32)
                  .fontSize(14)
                  .backgroundColor(Color.Transparent)
                  .onClick(() => { this.remove(item); })
              }
              .width('100%')
              .padding(14)
              .backgroundColor('#1e2440')
              .borderRadius(10)
            }
          }, (item: FavoriteItem) => item.structureId)
        }
        .width('100%')
        .layoutWeight(1)
        .padding({ left: 14, right: 14 })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#0f1222')
  }
}
