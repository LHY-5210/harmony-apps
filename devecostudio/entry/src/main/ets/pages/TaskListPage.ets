// 任务列表页：展示每次布置的任务，每个任务有按钮进入详情页
import { router } from '@kit.ArkUI';
import { TaskInfo, TaskParams, TASKS, statusColor } from '../model/TaskInfo';

@Entry
@Component
struct TaskListPage {
  @State tasks: TaskInfo[] = TASKS;

  build() {
    Column() {
      // 顶部标题栏
      Row({ space: 12 }) {
        Text('‹').fontSize(26).fontColor('#FFFFFF')
          .onClick(() => {
            router.back();
          })
        Text('任务列表').fontSize(18).fontWeight(FontWeight.Medium).fontColor('#FFFFFF')
      }
      .width('100%').height(56).padding({ left: 14, right: 14 })
      .backgroundColor('#3D7EF7')

      Text('共 ' + this.tasks.length + ' 个任务')
        .fontSize(12).fontColor('#999999')
        .width('94%').textAlign(TextAlign.Start).margin({ top: 10, bottom: 6 })

      if (this.tasks.length === 0) {
        Column({ space: 8 }) {
          Text('暂无任务').fontSize(17).fontColor('#999999')
          Text('老师布置新任务后会显示在这里').fontSize(13).fontColor('#BBBBBB')
        }
        .layoutWeight(1).width('100%').justifyContent(FlexAlign.Center)
      } else {
        List({ space: 12 }) {
          ForEach(this.tasks, (item: TaskInfo) => {
            ListItem() {
              Column({ space: 10 }) {
                // 标题行：任务名 + 状态标签
                Row() {
                  Text(item.title)
                    .fontSize(16).fontWeight(FontWeight.Medium).fontColor('#333333')
                    .layoutWeight(1).maxLines(1)
                  Text(item.status)
                    .fontSize(12).fontColor(statusColor(item.status))
                    .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                    .borderRadius(8)
                    .backgroundColor('#F5F6F8')
                }
                .width('100%')

                // 课程与截止时间
                Text('课程：' + item.course).fontSize(13).fontColor('#666666')
                  .width('100%').textAlign(TextAlign.Start)
                Text('截止：' + item.deadline).fontSize(13).fontColor('#E64545')
                  .width('100%').textAlign(TextAlign.Start)

                // 按钮：进入该任务的详细页面
                Button('查看详情')
                  .width('100%').height(38).fontSize(14)
                  .backgroundColor('#3D7EF7')
                  .onClick(() => {
                    const p: TaskParams = { id: item.id };
                    router.pushUrl({ url: 'pages/TaskDetailPage', params: p });
                  })
              }
              .width('100%').padding(14).borderRadius(12).backgroundColor('#FFFFFF')
            }
          }, (item: TaskInfo) => item.id.toString())
        }
        .layoutWeight(1).width('94%').padding({ bottom: 12 })
      }
    }
    .width('100%').height('100%').backgroundColor('#F2F3F5')
  }
}
