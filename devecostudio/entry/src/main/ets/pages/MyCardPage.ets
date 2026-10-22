// 我的名片页：编辑个人信息 + 实时生成二维码（数据存 Preferences）
import { router, promptAction } from '@kit.ArkUI';
import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { CardInfo, toVCard } from '../model/CardInfo';
import { FieldRow } from '../common/Widgets';

const PREF_NAME: string = 'mycard_store';
const KEY_MY: string = 'mycard_json';

@Entry
@Component
struct MyCardPage {
  @State myName: string = '';
  @State myCompany: string = '';
  @State myTitle: string = '';
  @State myPhone: string = '';
  @State myEmail: string = '';
  private pref: preferences.Preferences | undefined = undefined;

  aboutToAppear(): void {
    const ctx = getContext(this) as common.UIAbilityContext;
    preferences.getPreferences(ctx, { name: PREF_NAME }).then((p: preferences.Preferences) => {
      this.pref = p;
      p.get(KEY_MY, '').then((v: preferences.ValueType) => {
        if (typeof v === 'string' && v !== '') {
          const c = JSON.parse(v) as CardInfo;
          this.myName = c.name;
          this.myCompany = c.company;
          this.myTitle = c.title;
          this.myPhone = c.phone;
          this.myEmail = c.email;
        }
      });
    });
  }

  private buildMy(): CardInfo {
    const c = new CardInfo();
    c.name = this.myName;
    c.company = this.myCompany;
    c.title = this.myTitle;
    c.phone = this.myPhone;
    c.email = this.myEmail;
    c.groupName = '我的名片';
    return c;
  }

  private async save(): Promise<void> {
    if (this.myName.trim() === '') {
      promptAction.showToast({ message: '请输入姓名' });
      return;
    }
    if (this.pref === undefined) {
      return;
    }
    await this.pref.put(KEY_MY, JSON.stringify(this.buildMy()));
    await this.pref.flush();
    promptAction.showToast({ message: '我的名片已保存' });
  }

  build() {
    Column() {
      // 顶部栏
      Row() {
        Text('‹ 返回').fontSize(16).fontColor('#3D7EF7')
          .onClick(() => {
            router.back();
          })
        Text('我的名片').fontSize(18).fontWeight(FontWeight.Bold)
          .layoutWeight(1).textAlign(TextAlign.Center)
        Text('  ').fontSize(16)
      }
      .width('100%').padding(14)

      Scroll() {
        Column({ space: 14 }) {
          // 名片预览 + 实时二维码（特色功能）
          Column({ space: 8 }) {
            Text(this.myName !== '' ? this.myName : '未设置姓名')
              .fontSize(20).fontWeight(FontWeight.Bold)
            Text((this.myTitle !== '' ? this.myTitle : '未填写职位') +
              (this.myCompany !== '' ? ' · ' + this.myCompany : ''))
              .fontSize(13).fontColor('#666666')
            Text(this.myPhone !== '' ? this.myPhone : '未填写电话')
              .fontSize(14).fontColor('#333333')
            if (this.myName !== '') {
              QRCode(toVCard(this.buildMy())).width(160).height(160).margin({ top: 6 })
              Text('对方扫码即可识别（vCard 标准格式）')
                .fontSize(11).fontColor('#AAAAAA')
            }
          }
          .width('100%').padding(18).borderRadius(16).backgroundColor('#FFFFFF')
          .alignItems(HorizontalAlign.Center)

          // 编辑表单
          Column({ space: 12 }) {
            FieldRow({ label: '姓名*', placeholder: '请输入姓名', value: $myName })
            FieldRow({ label: '公司', placeholder: '请输入公司/单位', value: $myCompany })
            FieldRow({ label: '职位', placeholder: '请输入职位', value: $myTitle })
            FieldRow({ label: '电话*', placeholder: '请输入手机号', value: $myPhone })
            FieldRow({ label: '邮箱', placeholder: '请输入邮箱', value: $myEmail })
          }
          .width('100%').padding(14).borderRadius(12).backgroundColor('#FFFFFF')

          Button('保存我的名片')
            .width('100%').height(44).fontSize(16)
            .backgroundColor('#3D7EF7')
            .onClick(() => {
              this.save();
            })

          Blank().height(20)
        }
        .padding(14)
      }
      .layoutWeight(1).scrollBar(BarState.Off).align(Alignment.Top)
    }
    .width('100%').height('100%').backgroundColor('#F2F3F5')
  }
}
