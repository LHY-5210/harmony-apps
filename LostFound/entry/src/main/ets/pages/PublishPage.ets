import { ApiService } from '../common/network/ApiService';
import { Item, CATEGORIES, COLORS, Candidate } from '../model/Types';
import { ItemStore } from '../model/ItemStore';
import { SyncService } from '../common/network/SyncService';
import router from '@ohos.router';
import { fileIo } from '@kit.CoreFileKit';
import { picker } from '@kit.CoreFileKit';
import { image } from '@kit.ImageKit';

@Component
export struct PublishPage {
  @State type: 'lost' | 'found' = 'lost';
  @State category: string = '';
  @State color: string = '';
  @State location: string = '';
  @State description: string = '';
  @State ocrText: string = '';
  @State imagePath: string = '';
  @State imageB64: string = '';
  @State credentialQuestion: string = '';
  @State credentialAnswer: string = '';
  @State loading: boolean = false;
  @State aiMessage: string = '';
  @State candidates: Candidate[] = [];

  async pickPhoto() {
    try {
      const photoPicker = new picker.PhotoViewPicker();
      const select = new picker.PhotoSelectOptions();
      select.MIMEType = picker.PhotoViewMIMETypes.IMAGE_TYPE;
      select.maxSelectNumber = 1;
      const result = await photoPicker.select(select);
      if (result.photoUris.length === 0) {
        this.aiMessage = '未选择图片';
        return;
      }
      const uri = result.photoUris[0];
      this.imagePath = uri;
      const file = fileIo.openSync(uri, fileIo.OpenMode.READ_ONLY);
      const stat = fileIo.statSync(file.fd);
      const buf = new ArrayBuffer(stat.size);
      fileIo.readSync(file.fd, buf);
      fileIo.closeSync(file.fd);
      this.imageB64 = this.arrayBufferToBase64(buf);
      this.aiMessage = '图片已选择';
    } catch (e) {
      this.aiMessage = '选图失败: ' + String(e);
    }
  }

  private static readonly B64: string = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';

  private arrayBufferToBase64(buffer: ArrayBuffer): string {
    const bytes: Uint8Array = new Uint8Array(buffer);
    let binary: string = '';
    const len: number = bytes.byteLength;
    for (let i: number = 0; i < len; i += 3) {
      const b1: number = bytes[i];
      const b2: number = i + 1 < len ? bytes[i + 1] : 0;
      const b3: number = i + 2 < len ? bytes[i + 2] : 0;
      binary += PublishPage.B64[b1 >> 2];
      binary += PublishPage.B64[((b1 & 3) << 4) | (b2 >> 4)];
      binary += i + 1 < len ? PublishPage.B64[((b2 & 15) << 2) | (b3 >> 6)] : '=';
      binary += i + 2 < len ? PublishPage.B64[b3 & 63] : '=';
    }
    return binary;
  }

  async doClassify() {
    if (!this.imageB64) {
      this.aiMessage = '请先选择图片';
      return;
    }
    this.loading = true;
    try {
      const res = await ApiService.classify(this.imageB64);
      this.category = res.category;
      this.aiMessage = `AI 识别类别：${res.category}（置信度 ${(res.confidence * 100).toFixed(1)}%），可修正`;
    } catch (e) {
      this.aiMessage = '分类失败: ' + String(e);
    }
    this.loading = false;
  }

  async doOCR() {
    if (!this.imageB64) {
      this.aiMessage = '请先选择图片';
      return;
    }
    this.loading = true;
    try {
      const res = await ApiService.ocr(this.imageB64);
      this.ocrText = res.text;
      this.aiMessage = 'OCR 提取文字线索成功';
    } catch (e) {
      this.aiMessage = 'OCR 失败: ' + String(e);
    }
    this.loading = false;
  }

  async doVoice() {
    // 语音口述：录制模拟音频 → ASR → NER 填表
    this.loading = true;
    this.aiMessage = '正在录音并识别...';
    try {
      // 演示：将空音频送后端，后端 ASR 适配层返回示例口述文本
      const asrRes = await ApiService.asr('');
      const text = asrRes.text;
      const nerRes = await ApiService.ner(text);
      if (nerRes.category) this.category = nerRes.category;
      if (nerRes.color) this.color = nerRes.color;
      if (nerRes.location) this.location = nerRes.location;
      this.description = text;
      this.aiMessage = `语音识别：${text}`;
    } catch (e) {
      this.aiMessage = '语音识别失败: ' + String(e);
    }
    this.loading = false;
  }

  async submit() {
    if (!this.category) {
      this.aiMessage = '请填写或 AI 识别类别';
      return;
    }
    this.loading = true;
    const item: Item = new Item();
    item.itemId = 'local_' + Date.now() + '_' + Math.floor(Math.random() * 1000);
    item.type = this.type;
    item.category = this.category;
    item.color = this.color;
    item.location = this.location;
    item.eventTime = Date.now();
    item.description = this.description;
    item.ocrText = this.ocrText;
    item.imageUrl = this.imagePath;
    item.credentialQuestion = this.type === 'found' ? this.credentialQuestion : '';
    item.credentialAnswer = this.type === 'found' ? this.credentialAnswer : '';
    try {
      const resp = await ApiService.createItem(item);
      await ItemStore.upsert(item, true);
      this.candidates = resp.candidates || [];
      this.aiMessage = '发布成功！' + (this.candidates.length > 0
        ? `发现 ${this.candidates.length} 个匹配候选`
        : '暂无匹配，稍后系统将继续检索');
    } catch (e) {
      // 失败入待传队列
      await SyncService.enqueue(item);
      this.aiMessage = '网络异常，已加入待传队列，联网后自动重传';
    }
    this.loading = false;
  }

  @Builder
  Section(title: string) {
    Text(title).fontSize(14).fontColor('#666').margin({ top: 16, bottom: 6 })
  }

  build() {
    Scroll() {
      Column({ space: 8 }) {
        // 类型切换
        Row({ space: 12 }) {
          Button('失物登记')
            .backgroundColor(this.type === 'lost' ? '#ff4d4f' : '#e0e0e0')
            .fontColor(this.type === 'lost' ? '#fff' : '#666')
            .onClick(() => this.type = 'lost')
          Button('招领启事')
            .backgroundColor(this.type === 'found' ? '#52c41a' : '#e0e0e0')
            .fontColor(this.type === 'found' ? '#fff' : '#666')
            .onClick(() => this.type = 'found')
        }
        .width('100%').justifyContent(FlexAlign.Center).margin({ top: 12 })

        // 图片区
        this.Section('物品图片')
        Row({ space: 12 }) {
          if (this.imagePath) {
            Image(this.imagePath).width(100).height(100).objectFit(ImageFit.Cover).borderRadius(8)
          } else {
            Column() {
              Text('🖼️').fontSize(32)
              Text('选择图片').fontSize(11).fontColor('#999')
            }.width(100).height(100).backgroundColor('#f0f0f0').borderRadius(8)
              .justifyContent(FlexAlign.Center)
          }
          Button('相册选图').onClick(() => this.pickPhoto())
        }

        // AI 辅助
        Row({ space: 8 }) {
          Button('🤖 AI 分类').fontSize(12).onClick(() => this.doClassify()).enabled(!this.loading)
          Button('📝 OCR 文字').fontSize(12).onClick(() => this.doOCR()).enabled(!this.loading)
          Button('🎙️ 语音填表').fontSize(12).onClick(() => this.doVoice()).enabled(!this.loading)
        }
        .width('100%').justifyContent(FlexAlign.Center)

        Text(this.aiMessage).fontSize(12).fontColor('#1677ff').margin({ top: 4 }).width('95%')

        // 结构化字段
        this.Section('类别')
        TextInput({ placeholder: '如：校园卡', text: this.category })
          .onChange((v) => this.category = v)

        this.Section('颜色')
        Row({ space: 8 }) {
          ForEach(COLORS, (c: string) => {
            Text(c).fontSize(13).padding({ left: 12, right: 12, top: 6, bottom: 6 })
              .backgroundColor(this.color === c ? '#1677ff' : '#f0f0f0')
              .fontColor(this.color === c ? '#fff' : '#666')
              .borderRadius(16)
              .onClick(() => this.color = c)
          }, (c: string) => c)
        }

        this.Section('地点')
        TextInput({ placeholder: '如：图书馆二楼', text: this.location })
          .onChange((v) => this.location = v)

        this.Section('描述')
        TextArea({ placeholder: '详细描述物品特征...', text: this.description })
          .onChange((v) => this.description = v)
          .height(80)

        this.Section('OCR 文字线索')
        TextArea({ placeholder: 'OCR 提取的文字', text: this.ocrText })
          .onChange((v) => this.ocrText = v)
          .height(60).fontSize(12)

        // 招领凭证
        if (this.type === 'found') {
          this.Section('认领凭证问题（拾获者设置）')
          TextInput({ placeholder: '如：校园卡上的学号是？', text: this.credentialQuestion })
            .onChange((v) => this.credentialQuestion = v)
          TextInput({ placeholder: '正确答案', text: this.credentialAnswer })
            .onChange((v) => this.credentialAnswer = v)
        }

        Button('发 布').width('90%').height(48)
          .backgroundColor('#1677ff').margin({ top: 20, bottom: 20 })
          .enabled(!this.loading)
          .onClick(() => this.submit())

        // 候选匹配
        if (this.candidates.length > 0) {
          Text('匹配候选').fontSize(14).fontColor('#666').margin({ bottom: 8 })
          ForEach(this.candidates, (c: Candidate) => {
            Row() {
              Column({ space: 4 }) {
                Text(`候选物品 ${c.itemId.slice(0, 8)}`).fontSize(13).fontWeight(FontWeight.Medium)
                Text(`匹配分：${c.score}`).fontSize(12).fontColor(c.score >= 60 ? '#52c41a' : '#faad14')
              }
              Blank()
              Button('查看').fontSize(12).onClick(() => {
                router.pushUrl({ url: 'pages/DetailPage', params: { itemId: c.itemId } })
              })
            }.width('95%').padding(12).backgroundColor('#fff').borderRadius(8).margin({ bottom: 8 })
          }, (c: Candidate) => c.itemId)
        }
      }
      .width('100%').alignItems(HorizontalAlign.Start).padding({ left: 12, right: 12 })
    }
    .width('100%').height('100%').backgroundColor('#f5f5f5')
  }
}
