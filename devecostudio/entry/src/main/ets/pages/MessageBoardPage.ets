// 网页留言板页：使用 Web 组件加载 rawfile 中的本地 HTML
// 双向通信：
//   网页 → 原生：javaScriptProxy 注入 NativeBridge（提交留言、弹 Toast）
//   原生 → 网页：WebviewController.runJavaScript 调用 renderMessages / pushNotice
// 特色：加载进度条、前进/后退/刷新、网页标题同步原生标题栏、加载/失败友好提示
import { router } from '@kit.ArkUI';
import { webview } from '@kit.ArkWeb';
import { common } from '@kit.AbilityKit';
import { MessageStore } from '../model/MessageStore';
import { NativeBridge, WebBridge } from '../model/MessageBridge';

@Entry
@Component
struct MessageBoardPage {
  // Web 控制器：负责加载、导航、执行 JS
  private controller: webview.WebviewController = new webview.WebviewController();
  // 原生 → 网页 桥接
  private webBridge: WebBridge = new WebBridge(this.controller);
  // 留言持久化
  private store: MessageStore = new MessageStore();
  // 网页 → 原生 桥接（注入到 window.NativeBridge）
  private nativeBridge: NativeBridge = new NativeBridge(this.store, () => {
    this.refreshFromNative();
  });

  @State pageStatus: string = 'loading'; // loading / error / success
  @State progress: number = 0;
  @State webTitle: string = '留言板';
  @State canGoBack: boolean = false;
  @State canGoForward: boolean = false;

  aboutToAppear(): void {
    const ctx = getContext(this) as common.UIAbilityContext;
    this.store.init(ctx);
  }

  // 原生主动调用网页：把历史留言回传给网页渲染（打开页面时 / 提交成功后）
  private async refreshFromNative() {
    const list = await this.store.queryAll();
    this.webBridge.renderMessages(list);
  }

  build() {
    Column() {
      // ============ 顶部栏：标题同步 + 返回 ============
      Stack({ alignContent: Alignment.Start }) {
        Column({ space: 4 }) {
          Text(this.webTitle).fontSize(18).fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
          Text('WEB MESSAGE BOARD').fontSize(9).fontColor('#CCDDFF').letterSpacing(2)
        }
        .width('100%').padding({ top: 50, bottom: 16 }).alignItems(HorizontalAlign.Center)
        .linearGradient({ angle: 135, colors: [['#6D5BD0', 0], ['#9B6DF7', 1]] })

        Row({ space: 4 }) {
          Text('‹').fontSize(20).fontColor('#FFFFFF')
          Text('返回').fontSize(15).fontColor('#FFFFFF')
        }
        .padding({ left: 12, right: 14, top: 8, bottom: 8 })
        .margin({ left: 8, top: 42 })
        .borderRadius(18).backgroundColor('rgba(255,255,255,0.22)')
        .onClick(() => { router.back(); })
      }
      .width('100%')

      // ============ 加载进度条（加载中显示，完成后隐藏） ============
      if (this.pageStatus !== 'success') {
        Progress({ value: this.progress, total: 100, type: ProgressType.Linear })
          .width('100%').height(3).color('#9B6DF7')
          .backgroundColor('#F0ECFB')
      }

      // ============ 导航栏：后退 / 刷新 / 前进 ============
      Row() {
        this.navButton('‹', this.canGoBack, () => { this.controller.backward(); })
        this.navButton('↻', true, () => { this.controller.refresh(); })
        this.navButton('›', this.canGoForward, () => { this.controller.forward(); })
      }
      .width('100%').padding({ left: 12, right: 12, top: 8, bottom: 8 })
      .backgroundColor('#FFFFFF')

      // ============ Web 内容区（三态） ============
      Stack({ alignContent: Alignment.Center }) {
        Web({ src: $rawfile('message_board.html'), controller: this.controller })
          .width('100%').height('100%')
          .javaScriptAccess(true)
          .javaScriptProxy({
            object: this.nativeBridge,
            name: 'NativeBridge',
            methodList: ['showToast', 'submitMessage'],
            controller: this.controller
          })
          .onProgressChange((event) => {
            this.progress = event.newProgress;
            if (event.newProgress >= 100) {
              this.pageStatus = 'success';
            }
          })
          .onPageBegin(() => {
            this.pageStatus = 'loading';
            this.progress = 0;
          })
          .onPageEnd(() => {
            this.pageStatus = 'success';
            // 页面加载完成后，原生回传历史留言给网页渲染
            this.refreshFromNative();
            // 推送一条欢迎通知到网页
            this.webBridge.pushNotice('欢迎使用留言板，留言已由原生侧持久化保存');
            // 刷新导航按钮可用状态
            this.updateNavState();
          })
          .onErrorReceive(() => {
            this.pageStatus = 'error';
          })
          .onTitleReceive((event) => {
            if (event.title) {
              this.webTitle = event.title;
            }
          })

        // 加载中遮罩
        if (this.pageStatus === 'loading') {
          Column({ space: 12 }) {
            LoadingProgress().width(44).height(44).color('#9B6DF7')
            Text('页面加载中...').fontSize(14).fontColor('#888888')
          }
          .width('100%').height('100%')
          .backgroundColor('#EEF1F6')
        }

        // 加载失败遮罩
        if (this.pageStatus === 'error') {
          Column({ space: 16 }) {
            Text('⚠️').fontSize(56)
            Text('页面加载失败').fontSize(16).fontColor('#666666')
            Button('重新加载', { type: ButtonType.Capsule })
              .width(150).height(42).fontSize(15)
              .backgroundColor('#9B6DF7')
              .onClick(() => { this.controller.refresh(); })
          }
          .width('100%').height('100%')
          .backgroundColor('#EEF1F6')
        }
      }
      .layoutWeight(1).width('100%')
    }
    .width('100%').height('100%').backgroundColor('#EEF1F6')
  }

  // 导航按钮
  @Builder
  navButton(icon: string, enabled: boolean, action: () => void) {
    Text(icon)
      .width(40).height(36).borderRadius(10)
      .fontSize(20).textAlign(TextAlign.Center)
      .fontColor(enabled ? '#9B6DF7' : '#CCCCCC')
      .backgroundColor(enabled ? '#F4F0FD' : '#F5F5F5')
      .onClick(() => {
        if (enabled) {
          action();
        }
      })
  }

  // 刷新前进/后退按钮可用状态
  private updateNavState() {
    try {
      this.canGoBack = this.controller.accessBackward();
      this.canGoForward = this.controller.accessForward();
    } catch (e) {
      this.canGoBack = false;
      this.canGoForward = false;
    }
  }
}
