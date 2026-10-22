// 网页↔原生 桥接层：独立封装，职责清晰
// 1) 原生 → 网页：通过 WebviewController.runJavaScript 调用网页中暴露的全局函数
//    - window.renderMessages(list)  回传历史留言
//    - window.pushNotice(text)      向网页推送一条通知
// 2) 网页 → 原生：通过 javaScriptProxy 注入到网页 window.NativeBridge
//    - showToast(msg)              弹出原生 Toast
//    - submitMessage(name, content) 提交留言到原生数据库（异步，返回 boolean）
// 网页与原生通过本桥接对象通信，页面本身不直接操作数据库或 Web 控制器
import { webview } from '@kit.ArkWeb';
import { promptAction } from '@kit.ArkUI';
import { MessageStore } from './MessageStore';

// 供网页调用的原生方法集合（注入到 window.NativeBridge）
export class NativeBridge {
  private store: MessageStore;
  private onSubmitted?: () => void;

  constructor(store: MessageStore, onSubmitted?: () => void) {
    this.store = store;
    this.onSubmitted = onSubmitted;
  }

  // 网页调用：弹出原生 Toast
  showToast(msg: string): void {
    promptAction.showToast({ message: msg, duration: 2000 });
  }

  // 网页调用：提交留言到原生数据库，返回是否成功
  async submitMessage(name: string, content: string): Promise<boolean> {
    const ok: boolean = await this.store.add(name, content);
    if (ok && this.onSubmitted !== undefined) {
      this.onSubmitted();
    }
    return ok;
  }
}

// 原生 → 网页 的调用封装
export class WebBridge {
  private controller: webview.WebviewController;

  constructor(controller: webview.WebviewController) {
    this.controller = controller;
  }

  // 原生调用网页：把历史留言列表回传给网页渲染
  renderMessages(list: object[]): void {
    const json: string = JSON.stringify(list);
    this.controller.runJavaScript(`window.renderMessages(${json})`, () => {});
  }

  // 原生调用网页：向网页推送一条通知（顶部横幅）
  pushNotice(text: string): void {
    const safe: string = JSON.stringify(text);
    this.controller.runJavaScript(`window.pushNotice(${safe})`, () => {});
  }
}
