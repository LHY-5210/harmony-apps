// 个人信息页（首页）：只展示项目标题与个人信息
// 层级：渐变 Hero 区 → 上浮的个人信息卡 → "进入功能中心"入口按钮
// 功能模块统一放在功能中心页（FunctionPage）
import { router } from '@kit.ArkUI';
import {
  KEY_PROJECT_TITLE, KEY_PROJECT_SUBTITLE, KEY_NAME,
  KEY_STUDENT_ID, KEY_CLASS_NAME, KEY_COLLEGE
} from '../model/ProfileStore';

@Entry
@Component
struct HomePage {
  // 直接绑定 AppStorage：编辑页修改后这里立即更新
  @StorageLink(KEY_PROJECT_TITLE) projectTitle: string = '';
  @StorageLink(KEY_PROJECT_SUBTITLE) projectSubtitle: string = 'HarmonyOS ArkTS 课程实践项目';
  @StorageLink(KEY_NAME) myName: string = '张同学';
  @StorageLink(KEY_STUDENT_ID) studentId: string = '20240001';
  @StorageLink(KEY_CLASS_NAME) className: string = '计算机科学与技术 1 班';
  @StorageLink(KEY_COLLEGE) college: string = '信息工程学院';

  build() {
    Scroll() {
      Column() {
        // ============ 第一层：顶部 Hero 渐变区 ============
        Stack({ alignContent: Alignment.TopEnd }) {
          Column({ space: 6 }) {
            Text(this.projectTitle)
              .fontSize(24).fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
              .maxLines(1)
            Text(this.projectSubtitle)
              .fontSize(13).fontColor('#CCDDFF')
              .maxLines(1)
          }
          .width('100%').padding({ top: 56, bottom: 72, left: 16, right: 16 })
          .alignItems(HorizontalAlign.Center)
          .linearGradient({
            angle: 135,
            colors: [['#2F6FE6', 0], ['#5B8FF9', 1]]
          })

          // 编辑入口
          Row({ space: 4 }) {
            Text('✎').fontSize(14).fontColor('#FFFFFF')
            Text('编辑').fontSize(14).fontColor('#FFFFFF')
          }
          .padding({ left: 10, right: 10, top: 6, bottom: 6 })
          .margin({ top: 14, right: 16 })
          .borderRadius(14)
          .backgroundColor('rgba(255,255,255,0.25)')
          .onClick(() => {
            router.pushUrl({ url: 'pages/ProfileEditPage' });
          })
        }
        .width('100%')

        // ============ 第二层：个人信息卡（负边距上浮，阴影制造 Z 轴层级） ============
        Column({ space: 14 }) {
          Row({ space: 14 }) {
            Text(this.myName !== '' ? this.myName.charAt(0) : '?')
              .width(58).height(58).borderRadius(29)
              .backgroundColor('#3D7EF7')
              .fontColor('#FFFFFF').fontSize(25).textAlign(TextAlign.Center)

            Column({ space: 5 }) {
              Text(this.myName).fontSize(20).fontWeight(FontWeight.Bold).fontColor('#1A1A1A')
                .maxLines(1)
              Text(this.college + ' · ' + this.className)
                .fontSize(13).fontColor('#777777').maxLines(1)
            }
            .alignItems(HorizontalAlign.Start).layoutWeight(1)
          }
          .width('100%')

          Divider().color('#F0F2F5')

          // 学号 / 班级 / 学院 三格等宽信息
          Row() {
            this.profileCell('学号', this.studentId)
            Column().width(1).height(30).backgroundColor('#EEEEEE')
            this.profileCell('班级', this.className)
            Column().width(1).height(30).backgroundColor('#EEEEEE')
            this.profileCell('学院', this.college)
          }
          .width('100%')
        }
        .width('100%').padding(18).borderRadius(20).backgroundColor('#FFFFFF')
        .margin({ top: -46, left: 16, right: 16 })
        .shadow({ radius: 18, color: '#1F3D7EF7', offsetX: 0, offsetY: 8 })

        // ============ 第三层：进入功能中心的醒目入口 ============
        Row({ space: 10 }) {
          Text('⚙').fontSize(22).fontColor('#FFFFFF')
          Column({ space: 2 }) {
            Text('进入功能中心').fontSize(17).fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
            Text('电子名片 · 人物列表 · 计算器 · 天气 · 留言板 · 任务')
              .fontSize(11).fontColor('#DCE8FF')
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
          Text('›').fontSize(24).fontColor('#FFFFFF')
        }
        .width('100%').padding({ left: 20, right: 18, top: 18, bottom: 18 })
        .margin({ top: 28, left: 16, right: 16 })
        .borderRadius(20)
        .linearGradient({
          angle: 120,
          colors: [['#2F6FE6', 0], ['#4E8BF5', 1]]
        })
        .shadow({ radius: 16, color: '#293D7EF7', offsetX: 0, offsetY: 6 })
        .onClick(() => {
          router.pushUrl({ url: 'pages/FunctionPage' });
        })

        // 底部留白
        Column().height(30)
      }
      .width('100%')
    }
    .width('100%').height('100%').backgroundColor('#EEF1F6')
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
  }

  // 个人信息三格中的一格
  @Builder
  profileCell(label: string, value: string) {
    Column({ space: 4 }) {
      Text(label).fontSize(11).fontColor('#999999')
      Text(value !== '' ? value : '未填写')
        .fontSize(13).fontWeight(FontWeight.Medium)
        .fontColor(value !== '' ? '#333333' : '#BBBBBB')
        .maxLines(2).textAlign(TextAlign.Center)
    }
    .layoutWeight(1).alignItems(HorizontalAlign.Center)
  }
}
