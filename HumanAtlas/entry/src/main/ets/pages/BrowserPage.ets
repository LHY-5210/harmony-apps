import { common } from '@kit.AbilityKit';
import { webview } from '@kit.ArkWeb';
import { promptAction } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { FavoriteStore } from '../model/FavoriteStore';

const VIRTUAL_HOST: string = 'https://local.web';
const RAWFILE_ROOT: string = 'web/';

class NativeBridge {
  host: BrowserPage;
  constructor(host: BrowserPage) {
    this.host = host;
  }
  onStructureSelected(name: string, id: string): void {
    hilog.info(0x0000, 'HumanAtlas', 'onStructureSelected %{public}s', name);
    this.host.selectedName = name;
    this.host.addHistory();
    this.host.refreshFavoriteIcon();
  }
  onModelReady(d1: string, d2: string): void {
    this.host.modelReady = true;
  }
  onDebug(msg: string): void {
    hilog.info(0x0000, 'HumanAtlas', 'DBG %{public}s', msg);
  }
}

@Component
export struct BrowserPage {
  @State searchKeyword: string = '';
  @State selectedName: string = '';
  @State modelReady: boolean = false;
  @State favBtnIcon: string = '♡';
  private controller: webview.WebviewController = new webview.WebviewController();
  private ctx: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
  private bridge: NativeBridge = new NativeBridge(this);

  private mimeOf(path: string): string {
    if (path.endsWith('.html')) { return 'text/html'; }
    if (path.endsWith('.js')) { return 'application/javascript'; }
    if (path.endsWith('.css')) { return 'text/css'; }
    if (path.endsWith('.json')) { return 'application/json'; }
    if (path.endsWith('.svg')) { return 'image/svg+xml'; }
    if (path.endsWith('.png')) { return 'image/png'; }
    if (path.endsWith('.gz')) { return 'application/gzip'; }
    return 'application/octet-stream';
  }

  private onIntercept(event: OnInterceptRequestEvent): WebResourceResponse {
    const url: string = event.request.getRequestUrl();
    if (!url.startsWith(VIRTUAL_HOST)) {
      const miss: WebResourceResponse = new WebResourceResponse();
      miss.setResponseCode(404);
      miss.setReasonMessage('Not Found');
      miss.setResponseMimeType('text/plain');
      miss.setResponseData('404');
      return miss;
    }
    let rel: string = url.substring(VIRTUAL_HOST.length);
    const q: number = rel.indexOf('?');
    if (q >= 0) { rel = rel.substring(0, q); }
    if (rel.length === 0 || rel === '/') { rel = '/index.html'; }
    const rawPath: string = RAWFILE_ROOT + (rel.startsWith('/') ? rel.substring(1) : rel);

    const resp: WebResourceResponse = new WebResourceResponse();
    try {
      const bytes: Uint8Array = this.ctx.resourceManager.getRawFileContentSync(rawPath);
      resp.setResponseData(bytes.buffer as ArrayBuffer);
      resp.setResponseMimeType(this.mimeOf(rawPath));
      resp.setResponseEncoding('utf-8');
      resp.setResponseCode(200);
      resp.setReasonMessage('OK');
    } catch (e) {
      resp.setResponseCode(404);
      resp.setReasonMessage('Not Found');
      resp.setResponseMimeType('text/plain');
      resp.setResponseData('404');
    }
    return resp;
  }

  async refreshFavoriteIcon(): Promise<void> {
    if (this.selectedName.length === 0) { this.favBtnIcon = '♡'; return; }
    try {
      const fav: boolean = await FavoriteStore.getInstance().isFavorite(this.selectedName);
      this.favBtnIcon = fav ? '♥' : '♡';
    } catch (e) {
      this.favBtnIcon = '♡';
    }
  }

  async addHistory(): Promise<void> {
    if (this.selectedName.length === 0) { return; }
    try {
      await FavoriteStore.getInstance().addHistory(this.selectedName, this.selectedName, '');
      hilog.info(0x0000, 'HumanAtlas', 'history added %{public}s', this.selectedName);
    } catch (e) {
      hilog.error(0x0000, 'HumanAtlas', 'history failed %{public}s', JSON.stringify(e));
    }
  }

  private async toggleFavorite(): Promise<void> {
    if (this.selectedName.length === 0) {
      promptAction.showToast({ message: '请先在 3D 画面里点选一个结构' });
      return;
    }
    try {
      const fav: boolean = await FavoriteStore.getInstance().isFavorite(this.selectedName);
      if (fav) {
        await FavoriteStore.getInstance().removeFavorite(this.selectedName);
        this.favBtnIcon = '♡';
        promptAction.showToast({ message: '已取消收藏' });
      } else {
        await FavoriteStore.getInstance().addFavorite(this.selectedName, this.selectedName, '');
        this.favBtnIcon = '♥';
        promptAction.showToast({ message: '已收藏 ' + this.selectedName });
      }
    } catch (e) {
      promptAction.showToast({ message: '收藏操作失败' });
    }
  }

  private sendToWeb(method: string, arg: string): void {
    const code: string = 'if(window.__HA_BRIDGE__) window.__HA_BRIDGE__.' + method + '(' + JSON.stringify(arg) + ');';
    this.controller.runJavaScript(code);
  }

  build() {
    Column() {
      Row() {
        Button({ type: ButtonType.Normal, stateEffect: true }) {
          Text('←')
            .fontSize(22)
            .fontColor('#ccc')
            .fontWeight(FontWeight.Bold)
        }
        .width(36)
        .height(36)
        .backgroundColor(Color.Transparent)
        .onClick(() => {
          this.sendToWeb('goBack', '');
        })

        Text('人体解剖台')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
          .margin({ left: 8 })

        Blank()
        Text(this.modelReady ? '● 已加载' : '○ 加载中')
          .fontSize(11)
          .fontColor(this.modelReady ? '#56d4a7' : '#aab')
      }
      .width('100%')
      .padding({ left: 10, right: 16, top: 10, bottom: 6 })
      .backgroundColor('#1a1f35')

      Row() {
        TextInput({ placeholder: '搜索解剖结构（Heart / Femur）', text: this.searchKeyword })
          .layoutWeight(1)
          .height(36)
          .fontSize(13)
          .fontColor(Color.White)
          .placeholderColor('#666')
          .backgroundColor('#242a44')
          .borderRadius(8)
          .onChange((v: string) => { this.searchKeyword = v; })
          .onSubmit(() => {
            if (this.searchKeyword.length > 0) {
              this.sendToWeb('searchByName', this.searchKeyword);
            }
          })
      }
      .width('100%')
      .padding({ left: 14, right: 14, bottom: 6 })
      .backgroundColor('#1a1f35')

      Web({ src: VIRTUAL_HOST + '/index.html', controller: this.controller })
        .width('100%')
        .layoutWeight(1)
        .backgroundColor('#f2f3f3')
        .javaScriptAccess(true)
        .domStorageAccess(true)
        .zoomAccess(true)
        .mixedMode(MixedMode.All)
        .onInterceptRequest((event: OnInterceptRequestEvent) => {
          return this.onIntercept(event);
        })
        .javaScriptProxy({
          object: this.bridge,
          name: '__HA_NATIVE__',
          methodList: ['onStructureSelected', 'onModelReady', 'onDebug'],
          controller: this.controller
        })

      Row() {
        Button({ type: ButtonType.Normal, stateEffect: true }) {
          Column({ space: 1 }) {
            Text(this.favBtnIcon).fontSize(20).fontColor(this.favBtnIcon === '♥' ? '#ff4d6d' : '#ccc')
            Text('收藏').fontSize(10).fontColor('#aaa')
          }
        }
        .layoutWeight(1).height(48).backgroundColor(Color.Transparent)
        .onClick(() => { this.toggleFavorite(); })

        Divider().vertical(true).height(30).color('#3a4060')

        Button({ type: ButtonType.Normal, stateEffect: true }) {
          Column({ space: 1 }) {
            Text('⟲').fontSize(18).fontColor('#ccc')
            Text('爆炸').fontSize(10).fontColor('#aaa')
          }
        }
        .layoutWeight(1).height(48).backgroundColor(Color.Transparent)
        .onClick(() => { this.sendToWeb('setExplode', '50'); })

        Divider().vertical(true).height(30).color('#3a4060')

        Button({ type: ButtonType.Normal, stateEffect: true }) {
          Column({ space: 1 }) {
            Text('◎').fontSize(18).fontColor('#ccc')
            Text('隔离').fontSize(10).fontColor('#aaa')
          }
        }
        .layoutWeight(1).height(48).backgroundColor(Color.Transparent)
        .onClick(() => { this.sendToWeb('isolate', ''); })

        Divider().vertical(true).height(30).color('#3a4060')

        Button({ type: ButtonType.Normal, stateEffect: true }) {
          Column({ space: 1 }) {
            Text('↺').fontSize(18).fontColor('#ccc')
            Text('重置').fontSize(10).fontColor('#aaa')
          }
        }
        .layoutWeight(1).height(48).backgroundColor(Color.Transparent)
        .onClick(() => { this.sendToWeb('reset', ''); })
      }
      .width('100%')
      .height(52)
      .backgroundColor('#1a1f35')
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#1a1f35')
  }
}
