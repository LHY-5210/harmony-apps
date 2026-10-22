// 首页：名片列表（搜索 / 分组筛选 / 收藏过滤 / 长按删除 / 导入 / 新增）
import { router, promptAction } from '@kit.ArkUI';
import { pasteboard } from '@kit.BasicServicesKit';
import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { CardInfo, GROUPS, avatarColor, parseVCard, EditParams, DetailParams } from '../model/CardInfo';
import { CardDB } from '../model/CardDB';

@Entry
@Component
struct Index {
  @State list: CardInfo[] = [];
  @State keyword: string = '';
  @State currentGroup: string = '全部';
  @State onlyFav: boolean = false;
  private db: CardDB = new CardDB();

  aboutToAppear(): void {
    this.initDB();
  }

  // 每次回到本页都刷新（新增/编辑/删除后列表同步）
  onPageShow(): void {
    this.refresh();
  }

  private async initDB(): Promise<void> {
    const ctx = getContext(this) as common.UIAbilityContext;
    await this.db.init(ctx);
    await this.seedIfEmpty();
    this.refresh();
  }

  // 特色：仅在应用首次启动时预置一次示例数据（用 preferences 标记，避免删除后又被复原）
  private async seedIfEmpty(): Promise<void> {
    const ctx = getContext(this) as common.UIAbilityContext;
    const prefs: preferences.Preferences =
      await preferences.getPreferences(ctx, 'app_config');
    const seeded: boolean = prefs.getSync('card_seeded', false) as boolean;
    if (seeded) {
      return;
    }
    const n: number = await this.db.countAll();
    if (n > 0) {
      // 已有数据但未标记，补一下标记
      prefs.putSync('card_seeded', true);
      await prefs.flush();
      return;
    }
    const s1 = new CardInfo();
    s1.name = '张伟'; s1.company = '华为技术有限公司'; s1.title = '软件工程师';
    s1.phone = '13800000001'; s1.email = 'zhangwei@example.com';
    s1.address = '广东省深圳市龙岗区坂田'; s1.groupName = '同事';
    s1.favorite = 1; s1.note = '技术沙龙认识';
    const s2 = new CardInfo();
    s2.name = '李娜'; s2.company = '星辰大学'; s2.title = '辅导员';
    s2.phone = '13900000002'; s2.email = 'lina@example.com';
    s2.address = '湖北省武汉市洪山区'; s2.groupName = '同学';
    s2.note = '大学同班同学';
    const s3 = new CardInfo();
    s3.name = '王强'; s3.company = '强盛贸易公司'; s3.title = '采购经理';
    s3.phone = '13700000003'; s3.email = 'wangqiang@example.com';
    s3.address = '上海市浦东新区'; s3.groupName = '客户';
    s3.note = '项目合作方';
    await this.db.add(s1);
    await this.db.add(s2);
    await this.db.add(s3);
    // 标记已预置，后续删除名片不会再自动复原
    prefs.putSync('card_seeded', true);
    await prefs.flush();
  }

  private refresh(): void {
    this.db.queryAll(this.keyword, this.currentGroup, this.onlyFav).then((arr: CardInfo[]) => {
      this.list = arr;
    });
  }

  private allGroups(): string[] {
    return ['全部'].concat(GROUPS);
  }

  build() {
    Stack({ alignContent: Alignment.BottomEnd }) {
      Column() {
        // 标题栏
        Row() {
          Text('电子名片').fontSize(22).fontWeight(FontWeight.Bold).layoutWeight(1)
          Text('我的名片').fontSize(15).fontColor('#3D7EF7')
            .onClick(() => {
              router.pushUrl({ url: 'pages/MyCardPage' });
            })
        }
        .width('100%').padding({ left: 16, right: 16, top: 12, bottom: 4 })

        // 搜索框
        Search({ value: this.keyword, placeholder: '搜索姓名/公司/职位/电话' })
          .width('94%').margin({ top: 6 })
          .onChange((v: string) => {
            this.keyword = v;
            this.refresh();
          })

        // 分组筛选 + 只看收藏
        Row({ space: 8 }) {
          Scroll() {
            Row({ space: 8 }) {
              ForEach(this.allGroups(), (g: string) => {
                Text(g)
                  .fontSize(14)
                  .fontColor(this.currentGroup === g ? '#FFFFFF' : '#555555')
                  .backgroundColor(this.currentGroup === g ? '#3D7EF7' : '#FFFFFF')
                  .padding({ left: 14, right: 14, top: 6, bottom: 6 })
                  .borderRadius(16)
                  .onClick(() => {
                    this.currentGroup = g;
                    this.refresh();
                  })
              }, (g: string) => g)
            }
          }
          .scrollable(ScrollDirection.Horizontal).layoutWeight(1)

          Text(this.onlyFav ? '★收藏' : '☆收藏')
            .fontSize(14)
            .fontColor(this.onlyFav ? '#F7B500' : '#888888')
            .onClick(() => {
              this.onlyFav = !this.onlyFav;
              this.refresh();
            })
        }
        .width('94%').margin({ top: 8 })

        // 数量统计
        Text('共 ' + this.list.length + ' 张名片')
          .fontSize(12).fontColor('#999999')
          .width('94%').textAlign(TextAlign.Start).margin({ top: 4 })

        // 列表 / 空状态
        if (this.list.length === 0) {
          Column({ space: 8 }) {
            Text('暂无名片').fontSize(17).fontColor('#999999')
            Text('点击右下角 + 新增名片，或点“导入”从剪贴板导入')
              .fontSize(13).fontColor('#BBBBBB')
          }
          .layoutWeight(1).width('100%').justifyContent(FlexAlign.Center)
        } else {
          List({ space: 10 }) {
            ForEach(this.list, (item: CardInfo) => {
              ListItem() {
                Row({ space: 12 }) {
                  // 左侧：头像 + 信息（点击进入详情）
                  Row({ space: 12 }) {
                    // 头像：姓名首字 + 固定配色
                    Text(item.name !== '' ? item.name.charAt(0) : '?')
                      .width(48).height(48).borderRadius(24)
                      .backgroundColor(avatarColor(item.name))
                      .fontColor('#FFFFFF').fontSize(20).textAlign(TextAlign.Center)

                    Column({ space: 3 }) {
                      Row({ space: 6 }) {
                        Text(item.name).fontSize(17).fontWeight(FontWeight.Medium)
                        if (item.favorite === 1) {
                          Text('★').fontSize(14).fontColor('#F7B500')
                        }
                      }
                      Text((item.title !== '' ? item.title : '未填写职位') +
                        (item.company !== '' ? ' · ' + item.company : ''))
                        .fontSize(13).fontColor('#666666').maxLines(1)
                      Text(item.phone !== '' ? item.phone : '未填写电话')
                        .fontSize(13).fontColor('#999999')
                    }
                    .alignItems(HorizontalAlign.Start).layoutWeight(1)
                  }
                  .layoutWeight(1)
                  .onClick(() => {
                    const p: DetailParams = { id: item.id };
                    router.pushUrl({ url: 'pages/DetailPage', params: p });
                  })

                  // 右侧：删除按钮（独立区域，不会触发跳转）
                  Button('删除')
                    .fontSize(13).fontColor('#FFFFFF')
                    .backgroundColor('#E64545')
                    .height(32).padding({ left: 12, right: 12 })
                    .onClick(() => {
                      this.confirmDelete(item);
                    })
                }
                .width('100%').padding(12).borderRadius(12).backgroundColor('#FFFFFF')
              }
            }, (item: CardInfo) => item.id.toString() + '_' + item.favorite.toString())
          }
          .layoutWeight(1).width('94%').margin({ top: 6 })
        }
      }
      .width('100%').height('100%').backgroundColor('#F2F3F5')

      // 悬浮按钮：导入（剪贴板 vCard）+ 新增
      Column({ space: 12 }) {
        Button('导入')
          .width(72).height(36).fontSize(14)
          .backgroundColor('#FFFFFF').fontColor('#3D7EF7')
          .onClick(() => {
            this.importFromClipboard();
          })
        Button('+', { type: ButtonType.Circle })
          .width(56).height(56).fontSize(28)
          .backgroundColor('#3D7EF7')
          .onClick(() => {
            const p: EditParams = { mode: 'add', card: null };
            router.pushUrl({ url: 'pages/EditPage', params: p });
          })
      }
      .margin({ right: 20, bottom: 30 })
    }
    .width('100%').height('100%')
  }

  // 特色功能：从剪贴板导入 vCard 名片文本
  private importFromClipboard(): void {
    try {
      const text: string = pasteboard.getSystemPasteboard().getDataSync().getPrimaryText();
      if (text === '' || text.indexOf('BEGIN:VCARD') < 0) {
        promptAction.showToast({ message: '剪贴板中没有名片文本（需为VCARD格式）' });
        return;
      }
      const c: CardInfo = parseVCard(text);
      if (c.name === '') {
        promptAction.showToast({ message: '未找到姓名字段（FN:）' });
        return;
      }
      const p: EditParams = { mode: 'add', card: c };
      router.pushUrl({ url: 'pages/EditPage', params: p });
    } catch (e) {
      promptAction.showToast({ message: '读取剪贴板失败' });
    }
  }

  // 长按删除确认框
  private confirmDelete(item: CardInfo): void {
    AlertDialog.show({
      message: '确定删除名片「' + item.name + '」吗？',
      primaryButton: {
        value: '取消',
        action: () => {
        }
      },
      secondaryButton: {
        value: '删除',
        fontColor: '#E64545',
        action: () => {
          this.db.remove(item.id).then(() => {
            promptAction.showToast({ message: '已删除' });
            this.refresh();
          });
        }
      }
    });
  }
}
