// 人物列表页：展示团队成员，点击卡片展开/收起人物详情
import { router } from '@kit.ArkUI';
import { PEOPLE, Person } from '../model/PeopleInfo';

@Entry
@Component
struct PeoplePage {
  @State people: Person[] = PEOPLE;
  // 当前展开详情的人物 id，-1 表示全部收起
  @State expandedId: number = -1;

  build() {
    Column() {
      // 顶部标题栏（与其他功能页风格一致）
      Row({ space: 12 }) {
        Text('‹').fontSize(26).fontColor('#FFFFFF')
          .onClick(() => {
            router.back();
          })
        Text('人物列表').fontSize(18).fontWeight(FontWeight.Medium).fontColor('#FFFFFF')
      }
      .width('100%').height(56).padding({ left: 14, right: 14 })
      .backgroundColor('#3D7EF7')

      Text('共 ' + this.people.length + ' 位成员 · 点击卡片查看详情')
        .fontSize(12).fontColor('#999999')
        .width('94%').textAlign(TextAlign.Start).margin({ top: 10, bottom: 6 })

      List({ space: 12 }) {
        ForEach(this.people, (person: Person) => {
          ListItem() {
            Column({ space: 10 }) {
              // 基本信息行：彩色头像 + 姓名 + 职务 + 箭头
              Row({ space: 12 }) {
                Text(person.name.charAt(0))
                  .width(46).height(46).borderRadius(23)
                  .backgroundColor(person.color)
                  .fontColor('#FFFFFF').fontSize(20).textAlign(TextAlign.Center)
                Column({ space: 3 }) {
                  Text(person.name).fontSize(16).fontWeight(FontWeight.Medium).fontColor('#1A1A1A')
                  Text(person.role).fontSize(12).fontColor('#999999')
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)
                Text(this.expandedId === person.id ? '▴' : '▾')
                  .fontSize(14).fontColor('#BBBBBB')
              }
              .width('100%')

              // 详情区：点击展开/收起
              if (this.expandedId === person.id) {
                Divider().color('#F0F2F5')
                Text(person.detail)
                  .fontSize(13).fontColor('#666666').lineHeight(20)
                  .width('100%')
              }
            }
            .width('100%').padding(14)
            .borderRadius(14).backgroundColor('#FFFFFF')
            .border({ width: { left: 4 }, color: { left: person.color } })
            .onClick(() => {
              this.expandedId = this.expandedId === person.id ? -1 : person.id;
            })
          }
        }, (person: Person) => person.id.toString())
      }
      .width('94%').layoutWeight(1)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
    }
    .width('100%').height('100%')
    .backgroundColor('#EEF1F6')
  }
}
