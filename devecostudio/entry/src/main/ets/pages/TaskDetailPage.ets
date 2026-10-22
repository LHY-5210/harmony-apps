// 任务详情页：根据路由传入的任务 id 展示该任务的详细要求
import { router, promptAction } from '@kit.ArkUI';
import { TaskInfo, TaskParams, findTaskById, statusColor } from '../model/TaskInfo';

@Entry
@Component
struct TaskDetailPage {
  @State task: TaskInfo = new TaskInfo();
  @State loaded: boolean = false;

  aboutToAppear(): void {
    const params = router.getParams() as TaskParams;
    if (params === undefined || params === null) {
      return;
    }
    const t: TaskInfo | null = findTaskById(params.id);
    if (t !== null) {
      this.task = t;
      this.loaded = true;
    }
  }

  build() {
    Column() {
      // 顶部标题栏
      Row({ space: 12 }) {
        Text('‹').fontSize(26).fontColor('#FFFFFF')
          .onClick(() => {
            router.back();
          })
        Text('任务详情').fontSize(18).fontWeight(FontWeight.Medium).fontColor('#FFFFFF')
      }
      .width('100%').height(56).padding({ left: 14, right: 14 })
      .backgroundColor('#3D7EF7')

      if (!this.loaded) {
        Column({ space: 8 }) {
          Text('任务不存在').fontSize(17).fontColor('#999999')
          Button('返回列表')
            .width(120).height(38).fontSize(14)
            .backgroundColor('#3D7EF7')
            .onClick(() => {
              router.back();
            })
        }
        .layoutWeight(1).width('100%').justifyContent(FlexAlign.Center)
      } else {
        Scroll() {
          Column({ space: 14 }) {
            // 任务标题卡片
            Column({ space: 10 }) {
              Row() {
                Text(this.task.title)
                  .fontSize(19).fontWeight(FontWeight.Bold).fontColor('#222222')
                  .layoutWeight(1)
                Text(this.task.status)
                  .fontSize(12).fontColor(statusColor(this.task.status))
                  .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                  .borderRadius(8)
                  .backgroundColor('#F5F6F8')
              }
              .width('100%')

              this.metaRow('所属课程', this.task.course)
              this.metaRow('截止时间', this.task.deadline)
            }
            .width('100%').padding(16).borderRadius(14).backgroundColor('#FFFFFF')
            .alignItems(HorizontalAlign.Start)

            // 任务要求
            Column({ space: 8 }) {
              Text('任务要求')
                .fontSize(15).fontWeight(FontWeight.Medium).fontColor('#333333')
                .width('100%')
              Text(this.task.content)
                .fontSize(14).fontColor('#555555').lineHeight(24)
                .width('100%')
            }
            .width('100%').padding(16).borderRadius(14).backgroundColor('#FFFFFF')
            .alignItems(HorizontalAlign.Start)

            // 底部操作按钮
            Button('我知道了')
              .width('100%').height(42).fontSize(15)
              .backgroundColor('#3D7EF7')
              .onClick(() => {
                promptAction.showToast({ message: '加油完成任务！' });
              })
          }
          .width('100%').padding(14)
        }
        .layoutWeight(1).width('100%').align(Alignment.Top)
        .scrollBar(BarState.Off)
      }
    }
    .width('100%').height('100%').backgroundColor('#F2F3F5')
  }

  // 元信息行
  @Builder
  metaRow(label: string, value: string) {
    Row() {
      Text(label).fontSize(13).fontColor('#999999').width(64)
      Text(value).fontSize(13).fontColor('#333333').layoutWeight(1)
    }
    .width('100%')
  }
}
