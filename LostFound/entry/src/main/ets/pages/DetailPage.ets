import { ApiService } from '../common/network/ApiService';
import { Item, MatchPair, TimelineEvent, EVIDENCE_LEVELS, User } from '../model/Types';
import { AuthService } from '../common/network/AuthService';
import router from '@ohos.router';

@Entry
@Component
export struct DetailPage {
  @State itemId: string = '';
  @State item: Item | null = null;
  @State matches: MatchPair[] = [];
  @State loading: boolean = false;
  @State message: string = '';
  @State selectedMatch: number = 0;
  @State timeline: TimelineEvent[] = [];
  @State user: User | null = null;

  @State verifyAnswer: string = '';
  @State appealLevel: number = 2;
  @State appealText: string = '';

  async aboutToAppear() {
    const params = router.getParams() as Record<string, string>;
    this.itemId = params?.itemId || '';
    this.user = await AuthService.getUser();
    await this.load();
  }

  async load() {
    this.loading = true;
    try {
      this.item = await ApiService.getItem(this.itemId);
      const mr = await ApiService.listMatches(this.itemId);
      this.matches = mr.matches;
      if (this.matches.length > 0) {
        this.selectedMatch = this.matches[0].id;
        await this.loadTimeline();
      }
    } catch (e) {
      this.message = '加载失败: ' + String(e);
    }
    this.loading = false;
  }

  async loadTimeline() {
    if (this.selectedMatch === 0) return;
    try {
      const r = await ApiService.timeline(this.selectedMatch);
      this.timeline = r.events;
    } catch (e) {
      this.message = String(e);
    }
  }

  currentMatch(): MatchPair | null {
    return this.matches.find((m) => m.id === this.selectedMatch) || null;
  }

  isOwner(): boolean {
    return this.user !== null && this.item !== null && this.user.id === this.item.userId;
  }

  async doClaim() {
    if (!this.selectedMatch) return;
    try {
      const r = await ApiService.claim(this.selectedMatch);
      this.message = r.status === '核验中' ? '已进入凭证核验' : '已加入竞领队列';
      await this.load();
    } catch (e) {
      this.message = String(e);
    }
  }

  async doVerify() {
    if (!this.selectedMatch || !this.verifyAnswer) return;
    try {
      const r = await ApiService.verifyClaim(this.selectedMatch, this.verifyAnswer); // claimId may differ; simplified
      this.message = r.passed ? '凭证核验通过' : '凭证核验失败';
      this.verifyAnswer = '';
      await this.load();
    } catch (e) {
      this.message = String(e);
    }
  }

  async doConfirm() {
    if (!this.selectedMatch) return;
    try {
      await ApiService.confirm(this.selectedMatch);
      this.message = '认领已完成';
      await this.load();
    } catch (e) {
      this.message = String(e);
    }
  }

  async doClose() {
    if (!this.selectedMatch) return;
    try {
      await ApiService.closeMatch(this.selectedMatch);
      this.message = '已关闭';
      await this.load();
    } catch (e) {
      this.message = String(e);
    }
  }

  async doAppeal() {
    if (!this.selectedMatch) return;
    try {
      await ApiService.appeal(this.selectedMatch, this.appealLevel, this.appealText);
      this.message = '申诉已提交';
      this.appealText = '';
      await this.load();
    } catch (e) {
      this.message = String(e);
    }
  }

  formatTime(ts: number): string {
    if (!ts) return '';
    const d = new Date(ts);
    return `${d.getMonth() + 1}/${d.getDate()} ${d.getHours()}:${String(d.getMinutes()).padStart(2, '0')}`;
  }

  @Builder
  MatchDetail(m: MatchPair) {
    Column({ space: 10 }) {
      Row() {
        Text(`匹配 #${m.id}`).fontSize(14).fontWeight(FontWeight.Medium)
        Blank()
        Text(`得分 ${m.score}`).fontSize(13).fontColor(m.score >= 60 ? '#52c41a' : '#faad14')
      }.width('100%')

      Text(`状态：${m.status}`).fontSize(12).fontColor('#1677ff')

      // 因子明细
      Row({ space: 8 }) {
        ForEach(Object.keys(m.factors), (k: string) => {
          Text(`${k}:${Math.round((m.factors[k] || 0) * 100)}%`)
            .fontSize(10).fontColor('#888')
            .backgroundColor('#f5f5f5').padding(4).borderRadius(4)
        }, (k: string) => k)
      }

      // 凭证问题（招领物品显示）
      if (this.item?.type === 'found' && this.item.credentialQuestion) {
        Column() {
          Text(`凭证问题：${this.item.credentialQuestion}`).fontSize(12).fontColor('#666')
          TextInput({ placeholder: '输入答案以核验', text: this.verifyAnswer })
            .onChange((v) => this.verifyAnswer = v)
            .margin({ top: 6 })
          Button('提交核验').fontSize(12).onClick(() => this.doVerify())
        }.width('100%').padding(8).backgroundColor('#fffbe6').borderRadius(6).margin({ top: 6 })
      }

      // 操作按钮
      Row({ space: 8 }) {
        if (m.status === '待确认' && !this.isOwner()) {
          Button('发起认领').fontSize(12).backgroundColor('#1677ff').onClick(() => this.doClaim())
        }
        if (m.status === '凭证核验中' && !this.isOwner()) {
          Button('提交答案').fontSize(12).backgroundColor('#1677ff').onClick(() => this.doVerify())
        }
        if ((m.status === '凭证核验中' || m.status === '竞领中') && this.isOwner()) {
          Button('确认完成').fontSize(12).backgroundColor('#52c41a').onClick(() => this.doConfirm())
        }
        if (m.status === '已完成' && !this.isOwner()) {
          Button('冒领申诉').fontSize(12).backgroundColor('#ff4d4f').onClick(() => this.doAppeal())
        }
        if (m.status !== '已完成' && m.status !== '已关闭') {
          Button('关闭').fontSize(12).backgroundColor('#999').onClick(() => this.doClose())
        }
      }

      // 申诉表单
      if (m.status === '已完成') {
        Column({ space: 6 }) {
          Text('冒领申诉（证据等级须 L2/L3）').fontSize(12).fontColor('#ff4d4f')
          Select(EVIDENCE_LEVELS.map((l) => ({ value: l } as SelectOption)))
            .selected(this.appealLevel - 1)
            .onSelect((i) => this.appealLevel = i + 1)
          TextArea({ placeholder: '申诉说明', text: this.appealText })
            .onChange((v) => this.appealText = v).height(60)
        }.width('100%').padding(8).backgroundColor('#fff1f0').borderRadius(6).margin({ top: 6 })
      }
    }
    .width('100%').padding(12).backgroundColor('#fff').borderRadius(8)
  }

  build() {
    Column() {
      if (this.loading) {
        LoadingProgress().width(40).height(40).margin({ top: 40 })
      } else if (!this.item) {
        Text(this.message || '物品不存在').fontSize(14).margin({ top: 40 })
      } else {
        Scroll() {
          Column({ space: 12 }) {
            // 物品信息
            Column({ space: 6 }) {
              Row() {
                Text(this.item.type === 'lost' ? '🔍 失物登记' : '✨ 招领启事')
                  .fontSize(16).fontWeight(FontWeight.Bold)
                  .fontColor(this.item.type === 'lost' ? '#ff4d4f' : '#52c41a')
                Blank()
                Text(this.item.status).fontSize(12)
                  .fontColor(this.item.status === '已完成' ? '#52c41a' : '#1677ff')
              }
              if (this.item.imageUrl) {
                Image(this.item.imageUrl).width('100%').height(180).objectFit(ImageFit.Cover).borderRadius(8)
              }
              Text(`类别：${this.item.category}`).fontSize(14)
              if (this.item.color) Text(`颜色：${this.item.color}`).fontSize(13).fontColor('#666')
              if (this.item.location) Text(`地点：${this.item.location}`).fontSize(13).fontColor('#666')
              if (this.item.description) Text(`描述：${this.item.description}`).fontSize(13).fontColor('#666')
              if (this.item.ocrText) Text(`OCR 线索：${this.item.ocrText}`).fontSize(11).fontColor('#888')
                .backgroundColor('#f5f5f5').padding(6).borderRadius(4).width('100%')
            }
            .width('95%').padding(12).backgroundColor('#fff').borderRadius(8).alignItems(HorizontalAlign.Start)

            if (this.message) {
              Text(this.message).fontSize(12).fontColor('#1677ff').width('95%')
            }

            // 匹配列表
            Text(`匹配记录（${this.matches.length}）`).fontSize(14).fontWeight(FontWeight.Medium).width('95%')

            if (this.matches.length === 0) {
              Text('暂无匹配').fontSize(12).fontColor('#999').width('95%')
            } else {
              // 选择哪个匹配查看
              Scroll() {
                Row({ space: 8 }) {
                  ForEach(this.matches, (m: MatchPair) => {
                    Text(`#${m.id}`)
                      .fontSize(12)
                      .padding({ left: 10, right: 10, top: 4, bottom: 4 })
                      .backgroundColor(this.selectedMatch === m.id ? '#1677ff' : '#e0e0e0')
                      .fontColor(this.selectedMatch === m.id ? '#fff' : '#666')
                      .borderRadius(12)
                      .onClick(() => {
                        this.selectedMatch = m.id;
                        this.loadTimeline();
                      })
                  }, (m: MatchPair) => String(m.id))
                }
              }.scrollable(ScrollDirection.Horizontal).width('95%')

              if (this.currentMatch()) {
                this.MatchDetail(this.currentMatch()!)
              }

              // 状态时间线
              Text('状态时间线').fontSize(14).fontWeight(FontWeight.Medium).width('95%').margin({ top: 8 })
              Column({ space: 6 }) {
                ForEach(this.timeline, (ev: TimelineEvent) => {
                  Row({ space: 8 }) {
                    Text('●').fontSize(10).fontColor('#1677ff')
                    Column({ space: 2 }) {
                      Text(ev.event).fontSize(12)
                      Text(this.formatTime(ev.createdAt)).fontSize(10).fontColor('#999')
                    }.alignItems(HorizontalAlign.Start)
                  }.width('100%')
                }, (ev: TimelineEvent) => String(ev.id))
              }
              .width('95%').padding(12).backgroundColor('#fff').borderRadius(8).alignItems(HorizontalAlign.Start)
            }

            Blank().height(20)
          }
          .width('100%').alignItems(HorizontalAlign.Start)
        }
        .width('100%').layoutWeight(1)
      }
    }
    .width('100%').height('100%').backgroundColor('#f5f5f5')
  }
}
