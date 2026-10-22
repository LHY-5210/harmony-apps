// 新增 / 编辑名片页（新增、编辑、剪贴板导入预填 三种入口共用）
import { router, promptAction } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { CardInfo, GROUPS, EditParams } from '../model/CardInfo';
import { CardDB } from '../model/CardDB';
import { FieldRow } from '../common/Widgets';

@Entry
@Component
struct EditPage {
  @State isEdit: boolean = false;
  @State name: string = '';
  @State company: string = '';
  @State title: string = '';
  @State phone: string = '';
  @State email: string = '';
  @State address: string = '';
  @State groupName: string = '其他';
  @State note: string = '';
  private editId: number = 0;
  private db: CardDB = new CardDB();

  aboutToAppear(): void {
    const ctx = getContext(this) as common.UIAbilityContext;
    this.db.init(ctx);

    const params = router.getParams() as EditParams;
    if (params !== undefined && params !== null) {
      if (params.mode === 'edit' && params.card !== null) {
        this.isEdit = true;
        this.editId = params.card.id;
        this.fillFrom(params.card);
      } else if (params.card !== null) {
        this.fillFrom(params.card); // 导入预填
      }
    }
  }

  private fillFrom(c: CardInfo): void {
    this.name = c.name;
    this.company = c.company;
    this.title = c.title;
    this.phone = c.phone;
    this.email = c.email;
    this.address = c.address;
    this.groupName = c.groupName;
    this.note = c.note;
  }

  private fillBack(c: CardInfo): void {
    c.name = this.name.trim();
    c.company = this.company.trim();
    c.title = this.title.trim();
    c.phone = this.phone.trim();
    c.email = this.email.trim();
    c.address = this.address.trim();
    c.groupName = this.groupName;
    c.note = this.note.trim();
  }

  private async save(): Promise<void> {
    // 表单校验：姓名、电话必填
    if (this.name.trim() === '') {
      promptAction.showToast({ message: '请输入姓名' });
      return;
    }
    if (this.phone.trim() === '') {
      promptAction.showToast({ message: '请输入电话' });
      return;
    }
    const c = new CardInfo();
    c.id = this.editId;
    this.fillBack(c);

    if (this.isEdit) {
      // 编辑时保留原收藏状态与创建时间
      const old = await this.db.getById(this.editId);
      if (old !== null) {
        c.favorite = old.favorite;
        c.createTime = old.createTime;
      }
      await this.db.update(c);
      promptAction.showToast({ message: '已保存修改' });
    } else {
      c.favorite = 0;
      await this.db.add(c);
      promptAction.showToast({ message: '已添加名片' });
    }
    router.back();
  }

  build() {
    Column() {
      // 顶部栏
      Row() {
        Text('‹ 返回').fontSize(16).fontColor('#3D7EF7')
          .onClick(() => {
            router.back();
          })
        Text(this.isEdit ? '编辑名片' : '新增名片')
          .fontSize(18).fontWeight(FontWeight.Bold)
          .layoutWeight(1).textAlign(TextAlign.Center)
        Text('  ').fontSize(16)
      }
      .width('100%').padding(14)

      Scroll() {
        Column({ space: 14 }) {
          // 基本信息表单
          Column({ space: 12 }) {
            FieldRow({ label: '姓名*', placeholder: '请输入姓名', value: $name })
            FieldRow({ label: '公司', placeholder: '请输入公司/单位', value: $company })
            FieldRow({ label: '职位', placeholder: '请输入职位', value: $title })
            FieldRow({ label: '电话*', placeholder: '请输入手机号', value: $phone })
            FieldRow({ label: '邮箱', placeholder: '请输入邮箱', value: $email })
            FieldRow({ label: '地址', placeholder: '请输入地址', value: $address })

            Column({ space: 8 }) {
              Text('备注').fontSize(14).fontColor('#666666')
              TextArea({ text: this.note, placeholder: '认识场合、合作事项等' })
                .width('100%').height(70)
                .backgroundColor('#F5F6F8').borderRadius(8)
                .onChange((v: string) => {
                  this.note = v;
                })
            }
            .width('100%').alignItems(HorizontalAlign.Start)
          }
          .width('100%').padding(14).borderRadius(12).backgroundColor('#FFFFFF')

          // 分组选择
          Column({ space: 8 }) {
            Text('分组').fontSize(14).fontColor('#666666')
            Scroll() {
              Row({ space: 8 }) {
                ForEach(GROUPS, (g: string) => {
                  Text(g)
                    .fontSize(13)
                    .fontColor(this.groupName === g ? '#FFFFFF' : '#555555')
                    .backgroundColor(this.groupName === g ? '#3D7EF7' : '#F0F1F3')
                    .padding({ left: 14, right: 14, top: 6, bottom: 6 })
                    .borderRadius(14)
                    .onClick(() => {
                      this.groupName = g;
                    })
                }, (g: string) => g)
              }
            }
            .scrollable(ScrollDirection.Horizontal).width('100%')
          }
          .width('100%').padding(14).borderRadius(12).backgroundColor('#FFFFFF')
          .alignItems(HorizontalAlign.Start)

          Button('保存名片')
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
