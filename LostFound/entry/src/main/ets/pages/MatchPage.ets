import { ApiService } from '../common/network/ApiService';
import { Item, CATEGORIES } from '../model/Types';
import { ItemStore } from '../model/ItemStore';
import router from '@ohos.router';

@Component
export struct MatchPage {
  @State items: Item[] = [];
  @State filterType: string = '';
  @State filterCategory: string = '';
  @State loading: boolean = false;
  @State offline: boolean = false;

  async aboutToAppear() {
    await this.load();
  }

  async load() {
    this.loading = true;
    try {
      const resp = await ApiService.listItems(this.filterType, this.filterCategory, 1);
      this.items = resp.items;
      this.offline = false;
      if (this.items.length > 0) {
        await ItemStore.upsertAll(this.items, false);
      }
    } catch (e) {
      // 离线模式：从本地缓存读
      this.items = await ItemStore.listAll();
      this.offline = true;
    }
    this.loading = false;
  }

  @Builder
  ItemCard(item: Item) {
    Row() {
      Column({ space: 4 }) {
        Row({ space: 8 }) {
          Text(item.type === 'lost' ? '🔍 失物' : '✨ 招领')
            .fontSize(11).fontColor(item.type === 'lost' ? '#ff4d4f' : '#52c41a')
            .backgroundColor(item.type === 'lost' ? '#fff1f0' : '#f6ffed')
            .padding({ left: 6, right: 6, top: 2, bottom: 2 }).borderRadius(4)
          Text(item.category).fontSize(13).fontWeight(FontWeight.Medium)
          if (item.color) {
            Text(item.color).fontSize(12).fontColor('#888')
          }
        }
        Text(item.description || '暂无描述').fontSize(12).fontColor('#666').maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
        Row({ space: 12 }) {
          if (item.location) Text(`📍 ${item.location}`).fontSize(11).fontColor('#999')
          Text(item.status).fontSize(11)
            .fontColor(item.status === '已完成' ? '#52c41a' : (item.status === '待匹配' ? '#faad14' : '#1677ff'))
        }
      }
      .alignItems(HorizontalAlign.Start).layoutWeight(1)
      Image(item.imageUrl || '')
        .width(56).height(56).borderRadius(8).objectFit(ImageFit.Cover)
        .backgroundColor('#f0f0f0')
    }
    .width('100%').padding(12).backgroundColor('#fff').borderRadius(8)
    .margin({ bottom: 8 })
    .onClick(() => {
      router.pushUrl({ url: 'pages/DetailPage', params: { itemId: item.itemId } })
    })
  }

  build() {
    Column() {
      // 筛选条
      Row({ space: 8 }) {
        Text('类型:').fontSize(12)
        Select([
          { value: '全部' } as SelectOption, { value: '失物' } as SelectOption, { value: '招领' } as SelectOption
        ])
          .selected(this.filterType === '' ? 0 : (this.filterType === 'lost' ? 1 : 2))
          .onSelect((i) => {
            this.filterType = i === 0 ? '' : (i === 1 ? 'lost' : 'found');
            this.load();
          })
        Text('类别:').fontSize(12)
        Select([{ value: '全部' } as SelectOption, ...CATEGORIES.map((c) => ({ value: c } as SelectOption))])
          .selected(this.filterCategory === '' ? 0 : CATEGORIES.indexOf(this.filterCategory) + 1)
          .onSelect((i) => {
            this.filterCategory = i === 0 ? '' : CATEGORIES[i - 1];
            this.load();
          })
      }
      .width('100%').padding(12).backgroundColor('#fff')

      if (this.offline) {
        Text('离线模式，显示本地缓存').fontSize(11).fontColor('#faad14').padding({ left: 12, top: 4 })
      }

      if (this.loading) {
        LoadingProgress().width(40).height(40).margin({ top: 40 })
      } else if (this.items.length === 0) {
        Text('暂无物品').fontSize(14).fontColor('#999').margin({ top: 40 })
      } else {
        List() {
          ForEach(this.items, (item: Item) => {
            ListItem() {
              this.ItemCard(item)
            }
          }, (item: Item) => item.itemId)
        }
        .width('95%').layoutWeight(1)
      }
    }
    .width('100%').height('100%').backgroundColor('#f5f5f5')
  }
}
