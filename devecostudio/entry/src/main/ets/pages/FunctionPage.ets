// 功能中心页：从个人信息页进入，集中放置各功能模块的切换入口
// 布局：渐变标题栏（含返回）→ 功能切换按钮列表
import { router } from '@kit.ArkUI';

// 功能入口实体：切换按钮
class FeatureEntry {
  title: string;
  subtitle: string;
  icon: string;
  color: string;
  url: string;

  constructor(title: string, subtitle: string, icon: string, color: string, url: string) {
    this.title = title;
    this.subtitle = subtitle;
    this.icon = icon;
    this.color = color;
    this.url = url;
  }
}

@Entry
@Component
struct FunctionPage {
  // 页面切换按钮：点击切换至对应功能页面
  private features: FeatureEntry[] = [
    new FeatureEntry('电子名片', '管理联系人名片，支持增删改查', '👤', '#3D7EF7', 'pages/Index'),
    new FeatureEntry('人物列表', '团队成员介绍，点击查看详情', '👥', '#34B369', 'pages/PeoplePage'),
    new FeatureEntry('有声计算器', '按键语音播报的标准计算器', '🔢', '#FF9500', 'pages/CalculatorPage'),
    new FeatureEntry('天气预报', '省市查询实时天气与未来预报', '🌤️', '#1B7FD4', 'pages/WeatherPage'),
    new FeatureEntry('网页留言板', 'Web 双向通信的留言板', '💬', '#9B6DF7', 'pages/MessageBoardPage'),
    new FeatureEntry('任务列表', '查看任务列表与任务详情', '📋', '#5B6B7A', 'pages/TaskListPage')
  ];

  build() {
    Column() {
      // ============ 顶部渐变标题栏 ============
      Stack({ alignContent: Alignment.Start }) {
        Column({ space: 4 }) {
          Text('功能中心')
            .fontSize(22).fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
          Text('FUNCTION CENTER')
            .fontSize(10).fontColor('#CCDDFF').letterSpacing(2)
        }
        .width('100%')
        .padding({ top: 52, bottom: 26 })
        .alignItems(HorizontalAlign.Center)
        .linearGradient({
          angle: 135,
          colors: [['#2F6FE6', 0], ['#5B8FF9', 1]]
        })

        // 返回个人信息页
        Row({ space: 4 }) {
          Text('‹').fontSize(20).fontColor('#FFFFFF')
          Text('返回').fontSize(15).fontColor('#FFFFFF')
        }
        .padding({ left: 12, right: 14, top: 8, bottom: 8 })
        .margin({ left: 8, top: 44 })
        .borderRadius(18)
        .backgroundColor('rgba(255,255,255,0.22)')
        .onClick(() => {
          router.back();
        })
      }
      .width('100%')

      // ============ 功能切换按钮列表 ============
      Column({ space: 14 }) {
        ForEach(this.features, (item: FeatureEntry) => {
          this.switchBar(item)
        }, (item: FeatureEntry) => item.title)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 24, bottom: 30 })
    }
    .width('100%').height('100%')
    .backgroundColor('#EEF1F6')
  }

  // 页面切换按钮：彩色左边框标识 + 图标 + 标题/副标题 + 箭头，点击跳转对应功能页
  @Builder
  switchBar(item: FeatureEntry) {
    Row({ space: 12 }) {
      Text(item.icon)
        .width(44).height(44).borderRadius(12)
        .fontSize(22).textAlign(TextAlign.Center)
        .backgroundColor(item.color + '1A')
      Column({ space: 3 }) {
        Text(item.title)
          .fontSize(16).fontWeight(FontWeight.Medium).fontColor('#1A1A1A')
        Text(item.subtitle).fontSize(12).fontColor('#999999').maxLines(1)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      Text('›').fontSize(22).fontColor('#CCCCCC')
    }
    .width('100%').padding(14)
    .borderRadius(16).backgroundColor('#FFFFFF').clip(true)
    .border({ width: { left: 4 }, color: { left: item.color } })
    .shadow({ radius: 12, color: '#0F000000', offsetX: 0, offsetY: 4 })
    .onClick(() => {
      router.pushUrl({ url: item.url });
    })
  }
}
