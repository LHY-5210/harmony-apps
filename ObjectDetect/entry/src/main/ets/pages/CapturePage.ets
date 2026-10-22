import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { camera, cameraPicker } from '@kit.CameraKit';
import { image } from '@kit.ImageKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { promptAction } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { fileIo } from '@kit.CoreFileKit';
import { ImageUtil } from '../common/util/ImageUtil';
import { InferenceEngine } from '../model/InferenceEngine';
import { InferPayload, InferResult, DetectionBox } from '../model/Types';
import { DetectRecord, RecordStore } from '../model/RecordStore';
import { ModelManager } from '../model/ModelManager';

const TAG = 'ObjectDetect';
// 推理侧统一用低阈值保留候选，界面阈值只做过滤，拖动滑块即时生效
const CANDIDATE_FLOOR = 0.05;

// 可手工修正的常见类别（COCO 索引）
class ClassOption {
  id: number = 0;
  label: string = '';

  constructor(id: number, label: string) {
    this.id = id;
    this.label = label;
  }
}

const FIX_CLASSES: ClassOption[] = [
  new ClassOption(41, '水杯'), new ClassOption(67, '手机'), new ClassOption(66, '键盘'),
  new ClassOption(73, '书本'), new ClassOption(0, '人'), new ClassOption(5, '公交车'),
  new ClassOption(39, '瓶子'), new ClassOption(56, '椅子'), new ClassOption(64, '笔记本电脑'),
  new ClassOption(65, '鼠标'), new ClassOption(62, '电视'), new ClassOption(63, '遥控器')
];

@Component
export struct CapturePage {
  @State pixelMap: image.PixelMap | null = null;
  @State statusText: string = '请选择图片开始识别';
  @State imgInfo: string = '';
  @State timingText: string = '';
  @State confThreshold: number = 0.25;
  @State inferring: boolean = false;
  @State boxes: DetectionBox[] = [];
  @State compareText: string = '';
  @State comparing: boolean = false;

  private rgbaBuf: ArrayBuffer = new ArrayBuffer(0);
  private imgW: number = 0;
  private imgH: number = 0;
  private canvasW: number = 0;
  private canvasH: number = 0;
  private canvasReady: boolean = false;
  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private canvasCtx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);

  private modelPath(): string {
    const ctx: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    return ModelManager.resolvePath(ctx);
  }

  private async afterPixelMap(pm: image.PixelMap): Promise<void> {
    const w: number = await ImageUtil.widthOf(pm);
    const h: number = await ImageUtil.heightOf(pm);
    const buf: ArrayBuffer = await ImageUtil.readRgba(pm);
    this.rgbaBuf = buf;
    this.imgW = w;
    this.imgH = h;
    this.pixelMap = pm;
    this.boxes = [];
    this.imgInfo = `${w} × ${h}，RGBA ${(buf.byteLength / 1024).toFixed(0)} KB`;
    this.statusText = '图片已就绪，点击「开始识别」';
    this.timingText = '';
    this.drawBoxes();
  }

  private async pickFromGallery(): Promise<void> {
    try {
      const opts: photoAccessHelper.PhotoSelectOptions = new photoAccessHelper.PhotoSelectOptions();
      opts.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
      opts.maxSelectNumber = 1;
      const picker: photoAccessHelper.PhotoViewPicker = new photoAccessHelper.PhotoViewPicker();
      const result: photoAccessHelper.PhotoSelectResult = await picker.select(opts);
      if (result.photoUris.length === 0) {
        return;
      }
      const pm: image.PixelMap = await ImageUtil.uriToPixelMap(result.photoUris[0], 1280);
      await this.afterPixelMap(pm);
    } catch (e) {
      hilog.error(0x0000, TAG, 'pick failed %{public}s', JSON.stringify(e));
      promptAction.showToast({ message: '选图失败' });
    }
  }

  // 系统相机拍照：预览与前后摄切换由相机界面提供
  private async takePhoto(): Promise<void> {
    try {
      const ctx: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
      const profile: cameraPicker.PickerProfile = {
        cameraPosition: camera.CameraPosition.CAMERA_POSITION_BACK
      };
      const res: cameraPicker.PickerResult = await cameraPicker.pick(ctx,
        [cameraPicker.PickerMediaType.PHOTO], profile);
      if (res.resultCode !== 0 || res.resultUri.length === 0) {
        promptAction.showToast({ message: '未完成拍照' });
        return;
      }
      const pm: image.PixelMap = await ImageUtil.uriToPixelMap(res.resultUri, 1280);
      await this.afterPixelMap(pm);
    } catch (e) {
      hilog.error(0x0000, TAG, 'camera failed %{public}s', JSON.stringify(e));
      promptAction.showToast({ message: '相机不可用（模拟器可能无摄像头）' });
    }
  }

  // 内置示例图：不依赖相册内容，随时可演示
  private async loadSample(): Promise<void> {
    try {
      const ctx: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
      const bytes: Uint8Array = ctx.resourceManager.getRawFileContentSync('sample_bus.jpg');
      const src: image.ImageSource = image.createImageSource(bytes.buffer as ArrayBuffer);
      const pm: image.PixelMap = await src.createPixelMap();
      await this.afterPixelMap(pm);
    } catch (e) {
      hilog.error(0x0000, TAG, 'sample failed %{public}s', JSON.stringify(e));
      promptAction.showToast({ message: '示例图加载失败' });
    }
  }

  // TaskPool 会转移（transfer）参数中的 ArrayBuffer，导致原 buffer 失效，
  // 因此每次推理都传入副本，保证可重复识别与同步/异步对比
  private buildPayload(): InferPayload {
    const payload: InferPayload = new InferPayload();
    payload.rgba = this.rgbaBuf.slice(0);
    payload.imgW = this.imgW;
    payload.imgH = this.imgH;
    payload.modelPath = this.modelPath();
    payload.confThreshold = CANDIDATE_FLOOR;
    return payload;
  }

  private async runInference(): Promise<void> {
    if (this.rgbaBuf.byteLength === 0) {
      promptAction.showToast({ message: '请先选择图片' });
      return;
    }
    const engine: InferenceEngine = InferenceEngine.getInstance();
    if (engine.isRunning()) {
      promptAction.showToast({ message: '识别中，请稍候' });
      return;
    }
    this.inferring = true;
    this.statusText = '识别中…';
    const res: InferResult = await engine.inferAsync(this.buildPayload());
    this.inferring = false;
    if (res.error === 'BUSY') {
      promptAction.showToast({ message: '识别中，请稍候' });
      this.statusText = '识别中…';
      return;
    }
    if (res.error.length > 0) {
      hilog.error(0x0000, TAG, 'infer error %{public}s', res.error);
      this.statusText = '识别失败：' + res.error;
      return;
    }
    hilog.info(0x0000, TAG, 'infer OK boxes=%{public}d pre=%{public}dms infer=%{public}dms post=%{public}dms shape=%{public}s',
      res.boxes.length, res.timings.preMs, res.timings.inferMs, res.timings.postMs, res.outputShape);
    this.boxes = res.boxes;
    this.refreshResultText();
    this.timingText = `预处理 ${res.timings.preMs}ms / 推理 ${res.timings.inferMs}ms / 后处理 ${res.timings.postMs}ms`;
    this.drawBoxes();
  }

  // 同步调用 vs TaskPool 异步：先预热 worker，再分别计时
  private async runCompare(): Promise<void> {
    if (this.rgbaBuf.byteLength === 0) {
      promptAction.showToast({ message: '请先选择图片' });
      return;
    }
    const engine: InferenceEngine = InferenceEngine.getInstance();
    if (engine.isRunning() || this.comparing) {
      promptAction.showToast({ message: '识别中，请稍候' });
      return;
    }
    this.comparing = true;
    this.compareText = '对比中：预热 TaskPool…';

    await engine.inferAsync(this.buildPayload());

    this.compareText = '对比中：同步调用…';
    const t0: number = Date.now();
    const syncRes: InferResult = await engine.inferSync(this.buildPayload());
    const t1: number = Date.now();

    this.compareText = `同步 ${t1 - t0}ms（主线程阻塞），异步测量中…`;
    const a0: number = Date.now();
    const asyncRes: InferResult = await engine.inferAsync(this.buildPayload());
    const a1: number = Date.now();

    if (syncRes.error.length > 0 || asyncRes.error.length > 0) {
      hilog.error(0x0000, TAG, 'compare syncErr=%{public}s asyncErr=%{public}s',
        syncRes.error, asyncRes.error);
      this.compareText = '对比失败：' + syncRes.error + asyncRes.error;
    } else {
      this.compareText = `同步 ${t1 - t0}ms（阻塞 UI） vs 异步 ${a1 - a0}ms（UI 不阻塞，含调度）`;
    }
    this.comparing = false;
  }

  private visibleBoxes(): DetectionBox[] {
    const out: DetectionBox[] = [];
    for (let i = 0; i < this.boxes.length; i++) {
      if (this.boxes[i].score >= this.confThreshold) {
        out.push(this.boxes[i]);
      }
    }
    return out;
  }

  private refreshResultText(): void {
    const n: number = this.visibleBoxes().length;
    this.statusText = this.boxes.length === 0
      ? '未检测到目标，可下调阈值或更换图片'
      : `识别完成：${n} 个目标（候选 ${this.boxes.length} 个）`;
  }

  // 按类别统计，如「人×3、公交车×1」
  private summary(): string {
    const labels: string[] = [];
    const counts: number[] = [];
    const vis: DetectionBox[] = this.visibleBoxes();
    for (let i = 0; i < vis.length; i++) {
      const l: string = vis[i].label;
      let idx: number = labels.indexOf(l);
      if (idx < 0) {
        labels.push(l);
        counts.push(1);
      } else {
        counts[idx] = counts[idx] + 1;
      }
    }
    const parts: string[] = [];
    for (let i = 0; i < labels.length; i++) {
      parts.push(`${labels[i]}×${counts[i]}`);
    }
    return parts.join('、');
  }

  // 把检测框（原图坐标）映射到 ImageFit.Contain 的显示区域后绘制
  private drawBoxes(): void {
    if (!this.canvasReady || this.canvasW <= 0 || this.canvasH <= 0) {
      return;
    }
    this.canvasCtx.clearRect(0, 0, this.canvasW, this.canvasH);
    if (this.imgW <= 0 || this.imgH <= 0) {
      return;
    }
    const scale: number = Math.min(this.canvasW / this.imgW, this.canvasH / this.imgH);
    const dw: number = this.imgW * scale;
    const dh: number = this.imgH * scale;
    const ox: number = (this.canvasW - dw) / 2;
    const oy: number = (this.canvasH - dh) / 2;

    const vis: DetectionBox[] = this.visibleBoxes();
    this.canvasCtx.lineWidth = 2;
    this.canvasCtx.font = '12vp sans-serif';
    for (let i = 0; i < vis.length; i++) {
      const b: DetectionBox = vis[i];
      const x: number = ox + b.x1 * scale;
      const y: number = oy + b.y1 * scale;
      const w: number = (b.x2 - b.x1) * scale;
      const h: number = (b.y2 - b.y1) * scale;
      this.canvasCtx.strokeStyle = '#00E676';
      this.canvasCtx.strokeRect(x, y, w, h);
      const text: string = `${b.label} ${(b.score * 100).toFixed(0)}%`;
      const tw: number = this.canvasCtx.measureText(text).width;
      const ty: number = y - 18 >= 0 ? y - 18 : y;
      this.canvasCtx.fillStyle = '#00E676';
      this.canvasCtx.fillRect(x, ty, tw + 8, 18);
      this.canvasCtx.fillStyle = '#10142a';
      this.canvasCtx.fillText(text, x + 4, ty + 13);
    }
  }

  private fixClass(box: DetectionBox, opt: ClassOption): void {
    box.classId = opt.id;
    box.label = opt.label;
    this.boxes = this.boxes.slice();
    this.refreshResultText();
    this.drawBoxes();
  }

  private removeBox(box: DetectionBox): void {
    const idx: number = this.boxes.indexOf(box);
    if (idx >= 0) {
      this.boxes.splice(idx, 1);
      this.boxes = this.boxes.slice();
      this.refreshResultText();
      this.drawBoxes();
    }
  }

  // 本次识别结果 + 缩略图落库，供历史页查询
  private async saveRecord(): Promise<void> {
    if (this.pixelMap === null || this.visibleBoxes().length === 0) {
      promptAction.showToast({ message: '没有可保存的识别结果' });
      return;
    }
    try {
      const ctx: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
      await RecordStore.init(ctx);
      const id: string = `${Date.now()}-${Math.floor(Math.random() * 1000)}`;
      const dir: string = ctx.filesDir + '/thumbs';
      // mkdir 在目录已存在时会抛 13900015，需先判断
      let dirExists: boolean = false;
      try {
        dirExists = fileIo.accessSync(dir);
      } catch (e) {
        dirExists = false;
      }
      if (!dirExists) {
        await fileIo.mkdir(dir, true);
      }
      const thumbPath: string = dir + '/' + id + '.jpg';
      await ImageUtil.saveJpeg(this.pixelMap, thumbPath, 60);

      const vis: DetectionBox[] = this.visibleBoxes();
      const labels: string[] = [];
      for (let i = 0; i < vis.length; i++) {
        if (labels.indexOf(vis[i].label) < 0) {
          labels.push(vis[i].label);
        }
      }
      const rec: DetectRecord = new DetectRecord();
      rec.recordId = id;
      rec.createdAt = Date.now();
      rec.thumbPath = thumbPath;
      rec.imgW = this.imgW;
      rec.imgH = this.imgH;
      rec.summary = this.summary();
      rec.labels = labels.join(',');
      rec.boxesJson = JSON.stringify(vis);
      rec.synced = false;
      await RecordStore.insert(rec);
      this.statusText = `已保存：${this.summary()}`;
      promptAction.showToast({ message: '已保存到历史' });
    } catch (e) {
      hilog.error(0x0000, TAG, 'save failed %{public}s', JSON.stringify(e));
      promptAction.showToast({ message: '保存失败' });
    }
  }

  build() {
    Column({ space: 8 }) {
      Text('端侧物品识别')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(Color.White)
        .margin({ top: 10 })

      Row({ space: 8 }) {
        Button('相册选图')
          .height(34)
          .onClick(() => {
            this.pickFromGallery();
          })
        Button('示例图')
          .height(34)
          .onClick(() => {
            this.loadSample();
          })
        Button('拍照')
          .height(34)
          .onClick(() => {
            this.takePhoto();
          })
      }

      Stack() {
        if (this.pixelMap !== null) {
          Image(this.pixelMap)
            .width('100%')
            .height('100%')
            .objectFit(ImageFit.Contain)
        } else {
          Text('尚未选择图片')
            .fontSize(14)
            .fontColor('#667')
        }
        Canvas(this.canvasCtx)
          .width('100%')
          .height('100%')
          .onReady(() => {
            this.canvasReady = true;
            this.drawBoxes();
          })
      }
      .width('92%')
      .layoutWeight(1)
      .backgroundColor('#1a1f35')
      .borderRadius(10)
      .onAreaChange((oldVal: Area, newVal: Area) => {
        this.canvasW = Number(newVal.width);
        this.canvasH = Number(newVal.height);
        this.drawBoxes();
      })

      Text(this.imgInfo)
        .fontSize(12)
        .fontColor('#8a93b8')

      Row({ space: 8 }) {
        Text(`置信度 ${this.confThreshold.toFixed(2)}`)
          .fontSize(12)
          .fontColor('#aab')
          .width(86)
        Slider({ value: this.confThreshold, min: 0.05, max: 0.9, step: 0.05 })
          .layoutWeight(1)
          .onChange((v: number) => {
            this.confThreshold = v;
            this.refreshResultText();
            this.drawBoxes();
          })
      }
      .width('92%')

      Row({ space: 8 }) {
        Button(this.inferring ? '识别中…' : '开始识别')
          .layoutWeight(2)
          .height(38)
          .enabled(!this.inferring)
          .onClick(() => {
            this.runInference();
          })
        Button('保存记录')
          .layoutWeight(1)
          .height(38)
          .enabled(this.visibleBoxes().length > 0 && !this.inferring)
          .backgroundColor('#2b3350')
          .onClick(() => {
            this.saveRecord();
          })
      }
      .width('92%')

      Text(this.statusText)
        .fontSize(13)
        .fontColor('#aab')

      Text(this.timingText)
        .fontSize(12)
        .fontColor('#56d4a7')

      Row({ space: 8 }) {
        Button(this.comparing ? '对比中…' : '同步 vs 异步对比')
          .fontSize(12)
          .height(30)
          .backgroundColor('#2a3350')
          .enabled(!this.comparing && !this.inferring)
          .onClick(() => {
            this.runCompare();
          })
        if (this.compareText.length > 0) {
          Text(this.compareText)
            .fontSize(11)
            .fontColor('#ffb020')
            .layoutWeight(1)
            .maxLines(2)
        }
      }
      .width('92%')
      .justifyContent(FlexAlign.Start)

      if (this.visibleBoxes().length > 0) {
        Text(`清单：${this.summary()}`)
          .fontSize(13)
          .fontColor('#56d4a7')
          .width('92%')

        List({ space: 6 }) {
          ForEach(this.visibleBoxes(), (b: DetectionBox, idx: number) => {
            ListItem() {
              Row({ space: 6 }) {
                Text(`${idx + 1}. ${b.label}`)
                  .fontSize(13)
                  .fontColor(Color.White)
                  .width(72)
                Text(`${(b.score * 100).toFixed(0)}%`)
                  .fontSize(12)
                  .fontColor('#8a93b8')
                  .width(44)
                Select(FIX_CLASSES.map((c: ClassOption) => {
                  const o: SelectOption = { value: c.label };
                  return o;
                }))
                  .selected(Math.max(0, FIX_CLASSES.findIndex((c: ClassOption) => c.label === b.label)))
                  .value('修正类别')
                  .font({ size: 12 })
                  .height(28)
                  .layoutWeight(1)
                  .onSelect((i: number) => {
                    this.fixClass(b, FIX_CLASSES[i]);
                  })
                Button('删除')
                  .height(26)
                  .fontSize(12)
                  .backgroundColor('#3a2030')
                  .onClick(() => {
                    this.removeBox(b);
                  })
              }
              .width('100%')
            }
          }, (b: DetectionBox, idx: number) => `${idx}-${b.classId}-${b.x1.toFixed(0)}-${b.y1.toFixed(0)}-${b.score.toFixed(2)}`)
        }
        .width('92%')
        .height(140)
        .margin({ bottom: 6 })
      }
    }
    .width('100%')
    .height('100%')
  }
}
