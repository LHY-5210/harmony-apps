import { common } from '@kit.AbilityKit';
import { promptAction } from '@kit.ArkUI';
import { fileIo } from '@kit.CoreFileKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { AuthService } from '../common/network/AuthService';
import { CloudApi, CloudItem, RecordPage, StatsResult, CategoryStat, ModelInfo } from '../common/network/CloudApi';
import { SyncService, SyncSummary } from '../common/network/SyncService';
import { RecordStore, DetectRecord } from '../model/RecordStore';
import { ModelManager } from '../model/ModelManager';
import { HashUtil } from '../common/util/HashUtil';

const TAG = 'ObjectDetect';
const PAGE_SIZE: number = 10;
const TIME_LABELS: string[] = ['全部时间', '今天', '近 7 天'];

// 独立子组件：@Prop 保证父组件状态变化时能刷新（@Builder 按值传参不会刷新）
@Component
struct InfoRow {
  @Prop label: string = '';
  @Prop value: string = '';

  build() {
    Row() {
      Text(this.label)
        .fontSize(13)
        .fontColor('#8f9bb8')
        .width(96)
      Text(this.value)
        .fontSize(13)
        .fontColor('#e8ecf7')
        .layoutWeight(1)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .padding({ top: 4, bottom: 4 })
  }
}

@Component
export struct CloudPage {
  @Prop @Watch('onTick') tick: number = 0;
  @State deviceId: string = '';
  @State statusText: string = '未连接';
  @State localTotal: number = 0;
  @State pending: number = 0;
  @State syncMsg: string = '';
  @State syncing: boolean = false;
  @State busy: boolean = false;
  @State statsTotal: number = 0;
  @State categories: CategoryStat[] = [];
  @State items: CloudItem[] = [];
  @State total: number = 0;
  @State page: number = 1;
  @State timeIdx: number = 0;
  @State labelIdx: number = 0;
  @State labels: string[] = ['全部类别'];
  @State modelText: string = '未检查';
  @State localModelText: string = '';
  @State checking: boolean = false;
  @State downloading: boolean = false;
  @State updateAvailable: boolean = false;

  private inited: boolean = false;
  private cloudVersion: string = '';

  aboutToAppear(): void {
    this.init();
  }

  onTick(): void {
    if (this.inited) {
      this.refreshLocal();
    }
  }

  private async init(): Promise<void> {
    try {
      const ctx: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
      await AuthService.init(ctx);
      await RecordStore.init(ctx);
      this.inited = true;
      this.deviceId = AuthService.getDeviceId();
      await this.refreshLocal();
    } catch (e) {
      hilog.error(0x0000, TAG, 'cloud init failed %{public}s', JSON.stringify(e));
    }
  }

  private async refreshLocal(): Promise<void> {
    const all: DetectRecord[] = await RecordStore.query(0, '');
    this.localTotal = all.length;
    this.pending = RecordStore.pendingCount(all);
    const set: string[] = ['全部类别'];
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
    if (this.labelIdx >= this.labels.length) {
      this.labelIdx = 0;
    }
  }

  private timeOptions(): SelectOption[] {
    const out: SelectOption[] = [];
    for (let i = 0; i < TIME_LABELS.length; i++) {
      const o: SelectOption = { value: TIME_LABELS[i] };
      out.push(o);
    }
    return out;
  }

  private labelOptions(): SelectOption[] {
    const out: SelectOption[] = [];
    for (let i = 0; i < this.labels.length; i++) {
      const o: SelectOption = { value: this.labels[i] };
      out.push(o);
    }
    return out;
  }

  private fromTime(): number {
    const now: number = Date.now();
    if (this.timeIdx === 1) {
      const d: Date = new Date(now);
      d.setHours(0, 0, 0, 0);
      return d.getTime();
    }
    if (this.timeIdx === 2) {
      return now - 7 * 24 * 3600 * 1000;
    }
    return 0;
  }

  private currentLabel(): string {
    return this.labelIdx === 0 ? '' : this.labels[this.labelIdx];
  }

  private async doSync(): Promise<void> {
    if (this.syncing) {
      return;
    }
    this.syncing = true;
    this.statusText = '同步中…';
    try {
      const sum: SyncSummary = await SyncService.syncPending(50);
      this.syncMsg = sum.message;
      this.statusText = sum.offline ? '离线（记录已留存）' : '已连接';
      await this.refreshLocal();
      if (sum.ok > 0) {
        await this.loadStats();
        await this.loadPage();
      }
    } catch (e) {
      hilog.error(0x0000, TAG, 'sync failed %{public}s', JSON.stringify(e));
      this.statusText = '同步失败';
      this.syncMsg = '同步异常：' + JSON.stringify(e);
    }
    this.syncing = false;
  }

  private async loadStats(): Promise<void> {
    try {
      const s: StatsResult = await CloudApi.stats();
      this.statsTotal = s.total;
      this.categories = s.categories;
      this.statusText = '已连接';
    } catch (e) {
      hilog.error(0x0000, TAG, 'stats failed %{public}s', JSON.stringify(e));
      this.statusText = '云端不可达';
    }
  }

  private async loadPage(): Promise<void> {
    if (this.busy) {
      return;
    }
    this.busy = true;
    try {
      const r: RecordPage = await CloudApi.queryRecords(this.fromTime(), this.currentLabel(),
        this.page, PAGE_SIZE);
      this.items = r.items;
      this.total = r.total;
      this.statusText = '已连接';
    } catch (e) {
      hilog.error(0x0000, TAG, 'query failed %{public}s', JSON.stringify(e));
      this.statusText = '云端不可达';
      this.items = [];
      this.total = 0;
    }
    this.busy = false;
  }

  private async refreshCloud(): Promise<void> {
    this.page = 1;
    await this.loadStats();
    await this.loadPage();
  }

  // 拉取云端版本并与本地模型摘要比对，决定是否提示更新
  private async checkModel(): Promise<void> {
    if (this.checking) {
      return;
    }
    this.checking = true;
    this.modelText = '检查中…';
    try {
      const ctx: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
      const m: ModelInfo = await CloudApi.modelLatest();
      this.cloudVersion = m.version;
      this.modelText = `${m.version} · ${(m.size / 1024 / 1024).toFixed(1)} MB · sha ${m.sha256.substring(0, 8)}`;

      const localPath: string = ModelManager.resolvePath(ctx);
      const name: string = localPath.substring(localPath.lastIndexOf('/') + 1);
      const localVer: string = ModelManager.localVersion(ctx);
      try {
        const sha: string = await HashUtil.sha256File(localPath);
        this.localModelText = `${localVer} · ${name} · sha ${sha.substring(0, 8)}`;
      } catch (e) {
        this.localModelText = `${localVer} · ${name} · 读取失败`;
      }
      this.updateAvailable = localVer !== m.version;
      this.statusText = '已连接';
    } catch (e) {
      hilog.error(0x0000, TAG, 'check model failed %{public}s', JSON.stringify(e));
      this.modelText = '检查失败';
      this.statusText = '云端不可达';
    }
    this.checking = false;
  }

  // 下载云端模型到 active-版本.ms，下次识别自动加载新会话
  private async applyModel(): Promise<void> {
    if (this.downloading || this.cloudVersion.length === 0) {
      return;
    }
    this.downloading = true;
    this.statusText = '下载模型…';
    try {
      const ctx: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
      const dir: string = ctx.filesDir + '/models';
      try {
        if (!fileIo.accessSync(dir)) {
          fileIo.mkdirSync(dir, true);
        }
      } catch (e) {
        // 目录已存在
      }
      const tmp: string = `${dir}/active-${this.cloudVersion}.ms.tmp`;
      const size: number = await CloudApi.downloadModel(this.cloudVersion, tmp);
      const dst: string = ModelManager.apply(ctx, this.cloudVersion, tmp);
      const name: string = dst.substring(dst.lastIndexOf('/') + 1);
      this.localModelText = `${name} · ${(size / 1024 / 1024).toFixed(1)} MB（已应用）`;
      this.updateAvailable = false;
      this.statusText = '已连接';
      promptAction.showToast({ message: '模型已更新，下次识别生效' });
    } catch (e) {
      hilog.error(0x0000, TAG, 'apply model failed %{public}s', JSON.stringify(e));
      this.statusText = '模型下载失败';
      promptAction.showToast({ message: '模型下载失败' });
    }
    this.downloading = false;
  }

  private maxPage(): number {
    const n: number = Math.ceil(this.total / PAGE_SIZE);
    return n < 1 ? 1 : n;
  }

  private formatTime(ts: number): string {
    const d: Date = new Date(ts);
    const p = (n: number): string => n < 10 ? '0' + n : `${n}`;
    const mm: string = p(d.getMonth() + 1);
    const dd: string = p(d.getDate());
    const hh: string = p(d.getHours());
    const mi: string = p(d.getMinutes());
    return `${mm}-${dd} ${hh}:${mi}`;
  }

  build() {
    Scroll() {
      Column({ space: 12 }) {
        // ---- 账号与同步 ----
        Column({ space: 6 }) {
          InfoRow({ label: '设备标识', value: this.deviceId })
          InfoRow({ label: '连接状态', value: this.statusText })
          InfoRow({ label: '本地记录', value: `${this.localTotal} 条 · 待同步 ${this.pending}` })
          Row({ space: 10 }) {
            Button(this.syncing ? '同步中…' : `立即同步 (${this.pending})`)
              .fontSize(14)
              .layoutWeight(1)
              .height(40)
              .backgroundColor('#2f6bff')
              .enabled(!this.syncing)
              .onClick(() => { this.doSync(); })
            Button('刷新云端')
              .fontSize(14)
              .layoutWeight(1)
              .height(40)
              .backgroundColor('#2a3350')
              .onClick(() => { this.refreshCloud(); })
          }
          .width('100%')
          .margin({ top: 4 })

          if (this.syncMsg.length > 0) {
            Text(this.syncMsg)
              .fontSize(12)
              .fontColor('#7fd8a8')
              .width('100%')
          }
        }
        .width('100%')
        .padding(14)
        .backgroundColor('#1a1f35')
        .borderRadius(12)

        // ---- 云端统计 ----
        Column({ space: 8 }) {
          Row() {
            Text('云端记录')
              .fontSize(14)
              .fontColor('#8f9bb8')
            Blank()
            Text(`${this.statsTotal} 条`)
              .fontSize(14)
              .fontColor('#2f6bff')
          }
          .width('100%')

          if (this.categories.length === 0) {
            Text('暂无统计，先同步一条记录')
              .fontSize(12)
              .fontColor('#6a7490')
              .width('100%')
          } else {
            Flex({ wrap: FlexWrap.Wrap }) {
              ForEach(this.categories, (c: CategoryStat) => {
                Text(`${c.label} ×${c.count}`)
                  .fontSize(12)
                  .fontColor('#cfe0ff')
                  .padding({ left: 10, right: 10, top: 4, bottom: 4 })
                  .margin({ right: 8, bottom: 8 })
                  .backgroundColor('#243055')
                  .borderRadius(12)
              }, (c: CategoryStat) => c.label)
            }
            .width('100%')
          }
        }
        .width('100%')
        .padding(14)
        .backgroundColor('#1a1f35')
        .borderRadius(12)

        // ---- 云端查询 ----
        Column({ space: 10 }) {
          Row({ space: 8 }) {
            Select(this.timeOptions())
              .selected(this.timeIdx)
              .value(TIME_LABELS[this.timeIdx])
              .font({ size: 13 })
              .layoutWeight(1)
              .onSelect((index: number) => {
                this.timeIdx = index;
                this.page = 1;
                this.loadPage();
              })
            Select(this.labelOptions())
              .selected(this.labelIdx)
              .value(this.labels[this.labelIdx])
              .font({ size: 13 })
              .layoutWeight(1)
              .onSelect((index: number) => {
                this.labelIdx = index;
                this.page = 1;
                this.loadPage();
              })
          }
          .width('100%')

          if (this.items.length === 0) {
            Text('云端暂无匹配记录')
              .fontSize(12)
              .fontColor('#6a7490')
              .width('100%')
              .padding({ top: 6, bottom: 6 })
          } else {
            ForEach(this.items, (it: CloudItem) => {
              Column({ space: 4 }) {
                Row() {
                  Text(it.summary.length > 0 ? it.summary : '(无物品清单)')
                    .fontSize(14)
                    .fontColor('#e8ecf7')
                    .layoutWeight(1)
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                  Text(this.formatTime(it.created_at))
                    .fontSize(11)
                    .fontColor('#8f9bb8')
                }
                .width('100%')
                Text(`${it.device_id} · ${it.img_w}×${it.img_h}`)
                  .fontSize(11)
                  .fontColor('#6a7490')
                  .width('100%')
              }
              .width('100%')
              .padding({ top: 8, bottom: 8 })
              .border({ width: { bottom: 1 }, color: '#232a44' })
            }, (it: CloudItem) => it.record_id)
          }

          Row({ space: 10 }) {
            Button('上一页')
              .fontSize(13)
              .layoutWeight(1)
              .height(36)
              .backgroundColor('#2a3350')
              .enabled(this.page > 1 && !this.busy)
              .onClick(() => {
                if (this.page > 1) {
                  this.page = this.page - 1;
                  this.loadPage();
                }
              })
            Text(`第 ${this.page}/${this.maxPage()} 页 · 共 ${this.total} 条`)
              .fontSize(12)
              .fontColor('#8f9bb8')
            Button('下一页')
              .fontSize(13)
              .layoutWeight(1)
              .height(36)
              .backgroundColor('#2a3350')
              .enabled(this.page < this.maxPage() && !this.busy)
              .onClick(() => {
                if (this.page < this.maxPage()) {
                  this.page = this.page + 1;
                  this.loadPage();
                }
              })
          }
          .width('100%')
        }
        .width('100%')
        .padding(14)
        .backgroundColor('#1a1f35')
        .borderRadius(12)

        // ---- 模型版本与热更新 ----
        Column({ space: 8 }) {
          Row({ space: 8 }) {
            Text('模型版本')
              .fontSize(14)
              .fontColor('#8f9bb8')
            Blank()
            Button(this.checking ? '检查中…' : '检查更新')
              .fontSize(12)
              .height(30)
              .backgroundColor('#2a3350')
              .enabled(!this.checking && !this.downloading)
              .onClick(() => { this.checkModel(); })
            if (this.updateAvailable) {
              Button(this.downloading ? '下载中…' : '下载并应用')
                .fontSize(12)
                .height(30)
                .backgroundColor('#2f6bff')
                .enabled(!this.downloading)
                .onClick(() => { this.applyModel(); })
            }
          }
          .width('100%')
          Text(`云端：${this.modelText}`)
            .fontSize(12)
            .fontColor('#cfe0ff')
            .width('100%')
          if (this.localModelText.length > 0) {
            Text(`本地：${this.localModelText}`)
              .fontSize(12)
              .fontColor(this.updateAvailable ? '#ffb020' : '#7fd8a8')
              .width('100%')
          }
          if (this.updateAvailable) {
            Text('检测到模型版本差异，可下载后热更新')
              .fontSize(11)
              .fontColor('#ffb020')
              .width('100%')
          }
        }
        .width('100%')
        .padding(14)
        .backgroundColor('#1a1f35')
        .borderRadius(12)
      }
      .width('100%')
      .padding({ left: 14, right: 14, top: 14, bottom: 24 })
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
  }
}
