// 信息编辑页：编辑项目名称与个人信息，输入即同步到 AppStorage，主页面立即更新
import { router, promptAction } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import {
  KEY_PROJECT_TITLE, KEY_PROJECT_SUBTITLE, KEY_NAME,
  KEY_STUDENT_ID, KEY_CLASS_NAME, KEY_COLLEGE, ProfileStore
} from '../model/ProfileStore';

@Entry
@Component
struct ProfileEditPage {
  // 与主页面共享同一份 AppStorage 数据，输入后主页面立即变化
  @StorageLink(KEY_PROJECT_TITLE) projectTitle: string = '电子名片与任务管理';
  @StorageLink(KEY_PROJECT_SUBTITLE) projectSubtitle: string = 'HarmonyOS ArkTS 课程实践项目';
  @StorageLink(KEY_NAME) name: string = '张同学';
  @StorageLink(KEY_STUDENT_ID) studentId: string = '20240001';
  @StorageLink(KEY_CLASS_NAME) className: string = '计算机科学与技术 1 班';
  @StorageLink(KEY_COLLEGE) college: string = '信息工程学院';

  private ctx: common.UIAbilityContext | null = null;
  private saveTimerId: number = -1;

  aboutToAppear(): void {
    this.ctx = getContext(this) as common.UIAbilityContext;
  }

  // 离开页面时确保已落盘
  onPageHide(): void {
    void this.flushSave();
  }

  // 自动保存：输入变化后延迟一小段时间落盘到 preferences
  private scheduleSave(): void {
    if (this.saveTimerId !== -1) {
      clearTimeout(this.saveTimerId);
    }
    this.saveTimerId = setTimeout(() => {
      void this.flushSave();
    }, 600);
  }

  // 将 AppStorage 中的最新值写入本地 preferences（必须 await）
  private async flushSave(): Promise<void> {
    if (this.ctx === null) {
      return;
    }
    await ProfileStore.save(this.ctx);
  }

  build() {
    Column() {
      // 顶部标题栏
      Row({ space: 12 }) {
        Text('‹').fontSize(26).fontColor('#FFFFFF')
          .onClick(() => {
            router.back();
          })
        Text('编辑信息').fontSize(18).fontWeight(FontWeight.Medium).fontColor('#FFFFFF')
        Blank()
        Text('完成').fontSize(15).fontColor('#FFFFFF')
          .onClick(async () => {
            if (this.name.trim() === '' || this.projectTitle.trim() === '') {
              promptAction.showToast({ message: '项目名称和姓名不能为空' });
              return;
            }
            await this.flushSave();
            promptAction.showToast({ message: '已保存' });
            router.back();
          })
      }
      .width('100%').height(56).padding({ left: 14, right: 14 })
      .backgroundColor('#3D7EF7')

      Scroll() {
        Column({ space: 14 }) {
          Text('项目信息')
            .fontSize(15).fontWeight(FontWeight.Medium).fontColor('#333333')
            .width('100%')

          Column({ space: 12 }) {
            this.field('项目名', this.projectTitle, '请输入项目名称', (v: string) => {
              this.projectTitle = v;
              this.scheduleSave();
            })
            this.field('副标题', this.projectSubtitle, '请输入项目副标题', (v: string) => {
              this.projectSubtitle = v;
              this.scheduleSave();
            })
          }
          .width('100%').padding(14).borderRadius(14).backgroundColor('#FFFFFF')
          .alignItems(HorizontalAlign.Start)

          Text('个人信息')
            .fontSize(15).fontWeight(FontWeight.Medium).fontColor('#333333')
            .width('100%')

          Column({ space: 12 }) {
            this.field('姓名', this.name, '请输入姓名', (v: string) => {
              this.name = v;
              this.scheduleSave();
            })
            this.field('学号', this.studentId, '请输入学号', (v: string) => {
              this.studentId = v;
              this.scheduleSave();
            })
            this.field('班级', this.className, '请输入班级', (v: string) => {
              this.className = v;
              this.scheduleSave();
            })
            this.field('学院', this.college, '请输入学院', (v: string) => {
              this.college = v;
              this.scheduleSave();
            })
          }
          .width('100%').padding(14).borderRadius(14).backgroundColor('#FFFFFF')
          .alignItems(HorizontalAlign.Start)

          Text('提示：修改内容会自动保存，返回主页面即可看到更新。')
            .fontSize(12).fontColor('#999999').width('100%').textAlign(TextAlign.Center)
        }
        .width('100%').padding(14)
      }
      .layoutWeight(1).width('100%').align(Alignment.Top)
      .scrollBar(BarState.Off)
    }
    .width('100%').height('100%').backgroundColor('#F2F3F5')
  }

  @Builder
  field(label: string, value: string, placeholder: string, onChange: (v: string) => void) {
    Column({ space: 6 }) {
      Text(label).fontSize(13).fontColor('#888888').width('100%')
      TextInput({ text: value, placeholder: placeholder })
        .width('100%').height(42)
        .backgroundColor('#F5F6F8').borderRadius(8)
        .onChange((v: string) => {
          onChange(v);
        })
    }
    .width('100%').alignItems(HorizontalAlign.Start)
  }
}
