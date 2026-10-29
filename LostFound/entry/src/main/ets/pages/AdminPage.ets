import { ApiService } from '../common/network/ApiService';
import { Appeal, User } from '../model/Types';

@Component
export struct AdminPage {
  @State stats: Record<string, number> = {};
  @State appeals: Appeal[] = [];
  @State banned: User[] = [];
  @State message: string = '';

  async aboutToAppear() {
    await this.refresh();
  }

  async refresh() {
    try {
      this.stats = await ApiService.adminStats();
      const a = await ApiService.adminAppeals();
      this.appeals = a.appeals;
      const b = await ApiService.adminBanned();
      this.banned = b.users;
    } catch (e) {
      this.message = String(e);
    }
  }

  async decide(appealId: number, result: string) {
    try {
      await ApiService.decideAppeal(appealId, result);
      this.message = '已裁定';
      await this.refresh();
    } catch (e) {
      this.message = String(e);
    }
  }

  @Builder
  StatCard(label: string, value: number, color: string) {
    Column() {
      Text(String(value)).fontSize(20).fontWeight(FontWeight.Bold).fontColor(color)
      Text(label).fontSize(11).fontColor('#888')
    }
    .layoutWeight(1).padding(10).backgroundColor('#fff').borderRadius(8)
  }

  build() {
    Column() {
      Text('管理员控制台').fontSize(18).fontWeight(FontWeight.Bold).width('95%').margin({ top: 12 })

      if (this.message) {
        Text(this.message).fontSize(12).fontColor('#1677ff').width('95%')
      }

      // 统计概览
      Row({ space: 8 }) {
        this.StatCard('物品总数', this.stats['items'] || 0, '#1677ff')
        this.StatCard('匹配数', this.stats['matches'] || 0, '#52c41a')
      }.width('95%').margin({ top: 8 })
      Row({ space: 8 }) {
        this.StatCard('已完成', this.stats['completed'] || 0, '#52c41a')
        this.StatCard('待审申诉', this.stats['appeals_pending'] || 0, '#ff4d4f')
      }.width('95%').margin({ top: 8 })

      // 申诉裁定
      Text(`冒领申诉（${this.appeals.length}）`).fontSize(14).fontWeight(FontWeight.Medium)
        .width('95%').margin({ top: 16, bottom: 6 })
      if (this.appeals.length === 0) {
        Text('暂无申诉').fontSize(12).fontColor('#999').width('95%')
      } else {
        Column({ space: 8 }) {
          ForEach(this.appeals, (a: Appeal) => {
            Column({ space: 6 }) {
              Row() {
                Text(`申诉 #${a.id} · 匹配 #${a.matchId}`).fontSize(13).fontWeight(FontWeight.Medium)
                Blank()
                Text(a.status).fontSize(11)
                  .fontColor(a.status === '待裁定' ? '#faad14' : (a.status === '冒领成立' ? '#ff4d4f' : '#999'))
              }
              Text(`证据等级：L${a.evidenceLevel}`).fontSize(11).fontColor('#888')
              if (a.evidenceText) Text(a.evidenceText).fontSize(11).fontColor('#666')
              if (a.status === '待裁定') {
                Row({ space: 8 }) {
                  Button('冒领成立').fontSize(11).backgroundColor('#ff4d4f')
                    .onClick(() => this.decide(a.id, '成立'))
                  Button('驳回').fontSize(11).backgroundColor('#999')
                    .onClick(() => this.decide(a.id, '不成立'))
                }
              }
            }
            .width('100%').padding(10).backgroundColor('#fff').borderRadius(8)
          }, (a: Appeal) => String(a.id))
        }.width('95%')
      }

      // 禁领名单
      Text(`违规/禁领名单（${this.banned.length}）`).fontSize(14).fontWeight(FontWeight.Medium)
        .width('95%').margin({ top: 16, bottom: 6 })
      if (this.banned.length === 0) {
        Text('暂无违规用户').fontSize(12).fontColor('#999').width('95%')
      } else {
        Column({ space: 6 }) {
          ForEach(this.banned, (u: User) => {
            Row() {
              Text(u.username).fontSize(13).fontWeight(FontWeight.Medium).layoutWeight(1)
              Text(`信用分 ${u.creditScore}`).fontSize(11).fontColor('#ff4d4f')
              Text(`禁领 ${u.banClaimCount}`).fontSize(11).fontColor('#faad14').margin({ left: 8 })
            }.width('100%').padding(10).backgroundColor('#fff').borderRadius(8)
          }, (u: User) => String(u.id))
        }.width('95%')
      }

      Blank()
      Button('刷新').width('90%').margin({ bottom: 16 }).onClick(() => this.refresh())
    }
    .width('100%').height('100%').backgroundColor('#f5f5f5')
  }
}
