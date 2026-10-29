import { AuthService } from '../common/network/AuthService';
import { ApiService } from '../common/network/ApiService';
import { Item, User, CreditLog, CreditInfo } from '../model/Types';
import { SyncService } from '../common/network/SyncService';
import router from '@ohos.router';

@Component
export struct MyPage {
  @State user: User | null = null;
  @State items: Item[] = [];
  @State credit: CreditInfo | null = null;
  @State pending: number = 0;
  @State message: string = '';

  async aboutToAppear() {
    await this.refresh();
  }

  async refresh() {
    this.user = await AuthService.getUser();
    try {
      this.credit = await ApiService.myCredit();
      const r = await ApiService.myItems();
      this.items = r.items;
    } catch (e) {
      this.message = String(e);
    }
    this.pending = await SyncService.pendingCount();
  }

  async flush() {
    const n = await SyncService.flush();
    this.message = `已重传 ${n} 条`;
    this.pending = await SyncService.pendingCount();
    await this.refresh();
  }

  async logout() {
    await AuthService.logout();
    router.clear();
    router.replaceUrl({ url: 'pages/Index' });
  }

  build() {
    Column() {
      // 用户卡片
      Column({ space: 8 }) {
        Row() {
          Text(this.user?.username || '').fontSize(18).fontWeight(FontWeight.Bold)
          Blank()
          Text(this.user?.role === 'admin' ? '管理员' : '普通用户')
            .fontSize(11).backgroundColor('#1677ff').fontColor('#fff')
            .padding({ left: 8, right: 8, top: 2, bottom: 2 }).borderRadius(10)
        }
        Row({ space: 24 }) {
          Column() {
            Text(String(this.credit?.creditScore ?? 100)).fontSize(22).fontWeight(FontWeight.Bold).fontColor('#1677ff')
            Text('信用分').fontSize(11).fontColor('#888')
          }
          Column() {
            Text(String(this.credit?.banClaimCount ?? 0)).fontSize(22).fontWeight(FontWeight.Bold).fontColor('#ff4d4f')
            Text('禁领次数').fontSize(11).fontColor('#888')
          }
          Column() {
            Text(String(this.items.length)).fontSize(22).fontWeight(FontWeight.Bold).fontColor('#52c41a')
            Text('我的发布').fontSize(11).fontColor('#888')
          }
        }
        .width('100%').justifyContent(FlexAlign.SpaceAround)
      }
      .width('95%').padding(16).backgroundColor('#fff').borderRadius(8).margin({ top: 12 })

      if (this.pending > 0) {
        Row() {
          Text(`待传队列：${this.pending} 条`).fontSize(12).fontColor('#faad14')
          Blank()
          Button('立即重传').fontSize(11).height(28).onClick(() => this.flush())
        }.width('95%').padding(10).backgroundColor('#fffbe6').borderRadius(6).margin({ top: 8 })
      }

      if (this.message) {
        Text(this.message).fontSize(12).fontColor('#1677ff').width('95%').margin({ top: 6 })
      }

      // 我的发布
      Text('我的发布').fontSize(14).fontWeight(FontWeight.Medium).width('95%').margin({ top: 12, bottom: 6 })
      if (this.items.length === 0) {
        Text('暂无发布').fontSize(12).fontColor('#999').width('95%')
      } else {
        List() {
          ForEach(this.items, (it: Item) => {
            ListItem() {
              Row() {
                Column({ space: 4 }) {
                  Text(`${it.type === 'lost' ? '失物' : '招领'} · ${it.category}`).fontSize(13).fontWeight(FontWeight.Medium)
                  Text(it.description || '').fontSize(11).fontColor('#888').maxLines(1)
                }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                Text(it.status).fontSize(11)
                  .fontColor(it.status === '已完成' ? '#52c41a' : (it.status === '待匹配' ? '#faad14' : '#1677ff'))
              }
              .width('100%').padding(12).backgroundColor('#fff').borderRadius(8).margin({ bottom: 6 })
              .onClick(() => router.pushUrl({ url: 'pages/DetailPage', params: { itemId: it.itemId } }))
            }
          }, (it: Item) => it.itemId)
        }.width('95%').layoutWeight(1)
      }

      // 信用记录
      if (this.credit && this.credit.logs.length > 0) {
        Text('信用记录').fontSize(14).fontWeight(FontWeight.Medium).width('95%').margin({ top: 12, bottom: 6 })
        Column({ space: 4 }) {
          ForEach(this.credit.logs.slice(0, 8), (log: CreditLog) => {
            Row() {
              Text(log.reason).fontSize(12).layoutWeight(1)
              Text((log.delta > 0 ? '+' : '') + log.delta)
                .fontSize(12).fontColor(log.delta > 0 ? '#52c41a' : '#ff4d4f')
            }.width('100%').padding(8).backgroundColor('#fff').borderRadius(6)
          }, (log: CreditLog) => String(log.id))
        }.width('95%').margin({ bottom: 12 })
      }

      Button('退出登录').width('90%').backgroundColor('#ff4d4f').margin({ bottom: 16 })
        .onClick(() => this.logout())
    }
    .width('100%').height('100%').backgroundColor('#f5f5f5')
  }
}
