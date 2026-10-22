// 名片详情页：二维码名片 / 一键拨号 / 复制分享 / 收藏 / 编辑 / 删除
import { router, promptAction } from '@kit.ArkUI';
import { pasteboard } from '@kit.BasicServicesKit';
import { call } from '@kit.TelephonyKit';
import { common, Want } from '@kit.AbilityKit';
import { CardInfo, avatarColor, toVCard, fmtTime, DetailParams, EditParams } from '../model/CardInfo';
import { CardDB } from '../model/CardDB';

@Entry
@Component
struct DetailPage {
  @State card: CardInfo = new CardInfo();
  private db: CardDB = new CardDB();

  aboutToAppear(): void {
    const ctx = getContext(this) as common.UIAbilityContext;
    this.db.init(ctx).then(() => {
      this.loadCard();
    });
  }

  // 从编辑页返回后刷新显示
  onPageShow(): void {
    if (this.card.id > 0) {
      this.loadCard();
    }
  }

  private loadCard(): void {
    const params = router.getParams() as DetailParams;
    if (params === undefined || params === null) {
      return;
    }
    this.db.getById(params.id).then((c: CardInfo | null) => {
      if (c !== null) {
        this.card = c;
      }
    });
  }

  // 复制任意文本到剪贴板
  private copyText(label: string, text: string): void {
    if (text === '') {
      promptAction.showToast({ message: label + '未填写' });
      return;
    }
    const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, text);
    pasteboard.getSystemPasteboard().setData(data);
    promptAction.showToast({ message: label + '已复制' });
  }

  // 一键拨号（跳转系统拨号盘）
  private dial(): void {
    if (this.card.phone === '') {
      promptAction.showToast({ message: '未填写电话' });
      return;
    }
    try {
      call.makeCall(this.card.phone).catch(() => {
        this.dialFallback();
      });
    } catch (e) {
      this.dialFallback();
    }
  }

  private dialFallback(): void {
    promptAction.showToast({ message: '当前设备不支持拨号，已复制号码' });
    this.copyText('电话', this.card.phone);
  }

  // 发邮件（无邮件应用时降级为复制邮箱）
  private sendEmail(): void {
    if (this.card.email === '') {
      promptAction.showToast({ message: '未填写邮箱' });
      return;
    }
    const ctx = getContext(this) as common.UIAbilityContext;
    const want: Want = {
      action: 'ohos.want.action.viewData',
      uri: 'mailto:' + this.card.email
    };
    try {
      ctx.startAbility(want).catch(() => {
        promptAction.showToast({ message: '未找到邮件应用，已复制邮箱' });
        this.copyText('邮箱', this.card.email);
      });
    } catch (e) {
      promptAction.showToast({ message: '未找到邮件应用，已复制邮箱' });
      this.copyText('邮箱', this.card.email);
    }
  }

  private toggleFav(): void {
    const fav: number = this.card.favorite === 1 ? 0 : 1;
    this.db.setFavorite(this.card.id, fav).then(() => {
      this.loadCard();
    });
  }

  private confirmDelete(): void {
    AlertDialog.show({
      message: '确定删除名片「' + this.card.name + '」吗？',
      primaryButton: {
        value: '取消',
        action: () => {
        }
      },
      secondaryButton: {
        value: '删除',
        fontColor: '#E64545',
        action: () => {
          this.db.remove(this.card.id).then(() => {
            promptAction.showToast({ message: '已删除' });
            router.back();
          });
        }
      }
    });
  }

  build() {
    Column() {
      // 顶部栏
      Row() {
        Text('‹ 返回').fontSize(16).fontColor('#3D7EF7')
          .onClick(() => {
            router.back();
          })
        Text('名片详情').fontSize(18).fontWeight(FontWeight.Bold)
          .layoutWeight(1).textAlign(TextAlign.Center)
        Text(this.card.favorite === 1 ? '★' : '☆').fontSize(24).fontColor('#F7B500')
          .onClick(() => {
            this.toggleFav();
          })
      }
      .width('100%').padding(14)

      Scroll() {
        Column({ space: 12 }) {
          // 头像信息卡
          Column({ space: 6 }) {
            Text(this.card.name !== '' ? this.card.name.charAt(0) : '?')
              .width(72).height(72).borderRadius(36)
              .backgroundColor(avatarColor(this.card.name))
              .fontColor('#FFFFFF').fontSize(30).textAlign(TextAlign.Center)
            Text(this.card.name).fontSize(22).fontWeight(FontWeight.Bold)
            Text(this.card.title + (this.card.company !== '' ? ' · ' + this.card.company : ''))
              .fontSize(14).fontColor('#666666')
            Text('分组：' + this.card.groupName + '   创建：' + fmtTime(this.card.createTime))
              .fontSize(12).fontColor('#999999')
          }
          .width('100%').padding(20).borderRadius(16).backgroundColor('#FFFFFF')

          // 特色功能：二维码名片（vCard 标准格式）
          Column({ space: 8 }) {
            Text('名片二维码').fontSize(15).fontWeight(FontWeight.Medium)
            QRCode(toVCard(this.card)).width(170).height(170)
            Text('他人扫码即可识别；名片文本可复制后在本应用“导入”')
              .fontSize(11).fontColor('#AAAAAA')
          }
          .width('100%').padding(16).borderRadius(16).backgroundColor('#FFFFFF')
          .alignItems(HorizontalAlign.Center)

          // 联系信息 + 快捷操作
          Column({ space: 10 }) {
            Row({ space: 8 }) {
              Text('电话').fontSize(14).fontColor('#999999').width(44)
              Text(this.card.phone !== '' ? this.card.phone : '未填写')
                .fontSize(15).layoutWeight(1)
              Text('拨打').fontSize(14).fontColor('#3D7EF7')
                .onClick(() => {
                  this.dial();
                })
              Text('复制').fontSize(14).fontColor('#888888').margin({ left: 12 })
                .onClick(() => {
                  this.copyText('电话', this.card.phone);
                })
            }.width('100%')
            Divider().color('#F0F0F0')

            Row({ space: 8 }) {
              Text('邮箱').fontSize(14).fontColor('#999999').width(44)
              Text(this.card.email !== '' ? this.card.email : '未填写')
                .fontSize(15).layoutWeight(1)
              Text('邮件').fontSize(14).fontColor('#3D7EF7')
                .onClick(() => {
                  this.sendEmail();
                })
              Text('复制').fontSize(14).fontColor('#888888').margin({ left: 12 })
                .onClick(() => {
                  this.copyText('邮箱', this.card.email);
                })
            }.width('100%')
            Divider().color('#F0F0F0')

            Row({ space: 8 }) {
              Text('地址').fontSize(14).fontColor('#999999').width(44)
              Text(this.card.address !== '' ? this.card.address : '未填写')
                .fontSize(15).layoutWeight(1)
              Text('复制').fontSize(14).fontColor('#888888')
                .onClick(() => {
                  this.copyText('地址', this.card.address);
                })
            }.width('100%')
            Divider().color('#F0F0F0')

            Row({ space: 8 }) {
              Text('备注').fontSize(14).fontColor('#999999').width(44)
              Text(this.card.note !== '' ? this.card.note : '无')
                .fontSize(15).fontColor('#666666').layoutWeight(1)
            }.width('100%')
            Divider().color('#F0F0F0')

            // 分享整张名片文本
            Row() {
              Text('分享名片文本（vCard）').fontSize(14).fontColor('#3D7EF7')
                .onClick(() => {
                  this.copyText('名片', toVCard(this.card));
                })
            }.width('100%').justifyContent(FlexAlign.End)
          }
          .width('100%').padding(16).borderRadius(16).backgroundColor('#FFFFFF')
          .alignItems(HorizontalAlign.Start)

          // 操作按钮
          Row({ space: 12 }) {
            Button('编辑名片')
              .layoutWeight(1).backgroundColor('#3D7EF7')
              .onClick(() => {
                const p: EditParams = { mode: 'edit', card: this.card };
                router.pushUrl({ url: 'pages/EditPage', params: p });
              })
            Button('删除名片')
              .layoutWeight(1).backgroundColor('#E64545')
              .onClick(() => {
                this.confirmDelete();
              })
          }.width('100%')

          Blank().height(16)
        }
        .padding(14)
      }
      .layoutWeight(1).scrollBar(BarState.Off)
    }
    .width('100%').height('100%').backgroundColor('#F2F3F5')
  }
}
