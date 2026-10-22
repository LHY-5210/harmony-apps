import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { promptAction } from '@kit.ArkUI';
import { DetectRecord, RecordStore } from '../model/RecordStore';

const TAG = 'ObjectDetect';
const TIME_OPTIONS: string[] = ['全部时间', '今天', '近 7 天'];

function startOfToday(): number {
  const d: Date = new Date();
  d.setHours(0, 0, 0, 0);
  return d.getTime();
}

function formatTime(ms: number): string {
  const d: Date = new Date(ms);
  const mm: string = (d.getMonth() + 1).toString().padStart(2, '0');
  const dd: string = d.getDate().toString().padStart(2, '0');
  const hh: string = d.getHours().toString().padStart(2, '0');
  const mi: string = d.getMinutes().toString().padStart(2, '0');
  return `${mm}-${dd} ${hh}:${mi}`;
}

@Component
export struct HistoryPage {
  @Prop @Watch('reload') tick: number = 0;
  @State records: DetectRecord[] = [];
  @State timeIdx: number = 0;
  @State labelIdx: number = 0;
  @State labels: string[] = [];
  @State statusText: string = '';

  aboutToAppear(): void {
    this.reload();
  }

  private labelOptions(): string[] {
    const opts: string[] = ['全部类别'];
    for (let i = 0; i < this.labels.length; i++) {
      opts.push(this.labels[i]);
    }
    return opts;
  }

  private async reload(): Promise<void> {
    try {
      const ctx: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
      await RecordStore.init(ctx);
      // 先取全量以生成类别下拉项
      const all: DetectRecord[] = await RecordStore.query(0, '');
      const set: string[] = [];
      for (let i = 0; i < all.length; i++) {
        const parts: string[] = all[i].labels.split(',');
        for (let j = 0; j < parts.length; j++) {
          const p: string = parts[j].trim();
          if (p.length > 0 && set.indexOf(p) < 0) {
            set.push(p);
          }
        }
      }
      this.labels = set;
      if (this.labelIdx > set.length) {
        this.labelIdx = 0;
      }

      let from: number = 0;
      if (this.timeIdx === 1) {
        from = startOfToday();
      } else if (this.timeIdx === 2) {
        from = Date.now() - 7 * 24 * 3600 * 1000;
      }
      const label: string = this.labelIdx === 0 ? '' : set[this.labelIdx - 1];
      this.records = await RecordStore.query(from, label);
      this.statusText = this.records.length === 0
        ? '暂无符合条件的记录'
        : `共 ${this.records.length} 条记录`;
    } catch (e) {
      hilog.error(0x0000, TAG, 'history load failed %{public}s', JSON.stringify(e));
      this.statusText = '加载失败：' + JSON.stringify(e);
    }
  }

  private async removeRecord(rec: DetectRecord): Promise<void> {
    try {
      await RecordStore.deleteById(rec.recordId);
      await this.reload();
      promptAction.showToast({ message: '已删除' });
    } catch (e) {
      hilog.error(0x0000, TAG, 'delete failed %{public}s', JSON.stringify(e));
    }
  }

  build() {
    Column({ space: 8 }) {
      Text('识别历史')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(Color.White)
        .margin({ top: 10 })

      Row({ space: 8 }) {
        Select(TIME_OPTIONS.map((s: string) => {
          const o: SelectOption = { value: s };
          return o;
        }))
          .selected(this.timeIdx)
          .value(TIME_OPTIONS[this.timeIdx])
          .font({ size: 13 })
          .layoutWeight(1)
          .onSelect((i: number) => {
            this.timeIdx = i;
            this.reload();
          })
        Select(this.labelOptions().map((s: string) => {
          const o: SelectOption = { value: s };
          return o;
        }))
          .selected(this.labelIdx)
          .value(this.labelOptions()[this.labelIdx])
          .font({ size: 13 })
          .layoutWeight(1)
          .onSelect((i: number) => {
            this.labelIdx = i;
            this.reload();
          })
      }
      .width('92%')

      Text(this.statusText)
        .fontSize(12)
        .fontColor('#8a93b8')

      List({ space: 8 }) {
        ForEach(this.records, (r: DetectRecord) => {
          ListItem() {
            Row({ space: 10 }) {
              Image(`file://${r.thumbPath}`)
                .width(64)
                .height(64)
                .objectFit(ImageFit.Cover)
                .borderRadius(6)
                .backgroundColor('#1a1f35')
              Column({ space: 4 }) {
                Text(r.summary.length > 0 ? r.summary : '无目标')
                  .fontSize(14)
                  .fontColor(Color.White)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                Text(`${formatTime(r.createdAt)} · ${r.imgW}×${r.imgH}`)
                  .fontSize(12)
                  .fontColor('#8a93b8')
                Text(r.synced ? '已同步' : '待同步')
                  .fontSize(11)
                  .fontColor(r.synced ? '#56d4a7' : '#e0a44a')
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)

              Button('删除')
                .height(26)
                .fontSize(12)
                .backgroundColor('#3a2030')
                .onClick(() => {
                  this.removeRecord(r);
                })
            }
            .width('100%')
            .padding(8)
            .backgroundColor('#1a1f35')
            .borderRadius(8)
          }
        }, (r: DetectRecord) => r.recordId)
      }
      .width('92%')
      .layoutWeight(1)
      .margin({ bottom: 8 })
    }
    .width('100%')
    .height('100%')
  }
}
