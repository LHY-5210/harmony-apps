import { AuthService } from '../common/network/AuthService';
import { User } from '../model/Types';
import router from '@ohos.router';
import { MatchPage } from './MatchPage';
import { PublishPage } from './PublishPage';
import { MyPage } from './MyPage';
import { AdminPage } from './AdminPage';

@Entry
@Component
struct Index {
  @State currentIndex: number = 0;
  @State user: User | null = null;
  @State loggedIn: boolean = false;
  @State username: string = '';
  @State password: string = '';
  @State loading: boolean = false;
  @State isRegister: boolean = false;
  @State message: string = '';

  async aboutToAppear() {
    this.user = await AuthService.getUser();
    this.loggedIn = this.user !== null;
  }

  async doLogin() {
    if (!this.username || !this.password) {
      this.message = '请输入用户名和密码';
      return;
    }
    this.loading = true;
    try {
      if (this.isRegister) {
        await AuthService.register(this.username, this.password);
        this.message = '注册成功，请登录';
        this.isRegister = false;
      } else {
        const u = await AuthService.login(this.username, this.password);
        this.user = u;
        this.loggedIn = true;
        this.message = '';
      }
    } catch (e) {
      this.message = String(e);
    }
    this.loading = false;
  }

  async logout() {
    await AuthService.logout();
    this.user = null;
    this.loggedIn = false;
    this.username = '';
    this.password = '';
  }

  @Builder
  LoginView() {
    Column({ space: 16 }) {
      Text('校园智能失物招领')
        .fontSize(28).fontWeight(FontWeight.Bold).fontColor('#1677ff')
        .margin({ top: 60 })
      Text('端侧 AI 采集结构化 · 后端匹配与流程管理')
        .fontSize(12).fontColor('#888')

      Column({ space: 12 }) {
        TextInput({ placeholder: '用户名（内置 admin/admin123 或 demo/123456）', text: this.username })
          .onChange((v) => this.username = v)
          .height(48)
        TextInput({ placeholder: '密码', text: this.password })
          .type(InputType.Password)
          .onChange((v) => this.password = v)
          .height(48)

        Button(this.isRegister ? '注 册' : '登 录')
          .width('100%').height(48)
          .backgroundColor('#1677ff')
          .onClick(() => this.doLogin())
          .enabled(!this.loading)

        Text(this.loading ? '处理中...' : this.message)
          .fontSize(12).fontColor(this.message.startsWith('注册成功') ? '#52c41a' : '#ff4d4f')

        Text(this.isRegister ? '已有账号？去登录' : '没有账号？去注册')
          .fontSize(13).fontColor('#1677ff')
          .onClick(() => { this.isRegister = !this.isRegister; this.message = ''; })
      }
      .width('90%')
      .padding(20)
      .backgroundColor('#fff')
      .borderRadius(12)
      .margin({ top: 40 })

      Blank()
    }
    .width('100%').height('100%')
    .backgroundColor('#f5f5f5')
  }

  @Builder
  TabView() {
    Column() {
      Tabs({ barPosition: BarPosition.End, index: this.currentIndex }) {
        TabContent() {
          MatchPage()
        }.tabBar(this.tabBar(0, '广场', '📋'))

        TabContent() {
          PublishPage()
        }.tabBar(this.tabBar(1, '发布', '➕'))

        TabContent() {
          MyPage()
        }.tabBar(this.tabBar(2, '我的', '👤'))

        if (this.user?.role === 'admin') {
          TabContent() {
            AdminPage()
          }.tabBar(this.tabBar(3, '管理', '⚙️'))
        }
      }
      .barHeight(56)
      .onChange((i) => this.currentIndex = i)
      .width('100%').layoutWeight(1)
    }
    .width('100%').height('100%')
  }

  @Builder
  tabBar(index: number, title: string, icon: string) {
    Column() {
      Text(icon).fontSize(20)
      Text(title).fontSize(11)
        .fontColor(this.currentIndex === index ? '#1677ff' : '#999')
    }
    .width('100%').height(56).justifyContent(FlexAlign.Center)
  }

  build() {
    if (!this.loggedIn) {
      this.LoginView()
    } else {
      this.TabView()
    }
  }
}
