// 天气预报页：省-市两级选择 → 查询实时天气与未来 5 天预报
// 三态 UI：加载中 / 失败(含无网,可重试) / 成功
// 特色：记住上次选择的城市（Preferences 持久化）；体感生活提示
// 网络与解析全部封装在 WeatherService，本页只消费 WeatherResult
import { router } from '@kit.ArkUI';
import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { Province, CityCoord, buildProvinces } from '../model/RegionList';
import { CurrentWeather, DailyItem, WeatherResult, WeatherText, WindHelper } from '../model/WeatherInfo';
import { WeatherService } from '../model/WeatherService';

const STORE_NAME: string = 'weather_store';

@Entry
@Component
struct WeatherPage {
  // 页面状态：loading / success / error
  @State pageState: string = 'loading';
  @State errMsg: string = '';
  @State cur: CurrentWeather = new CurrentWeather();
  @State daily: DailyItem[] = [];

  // 省市选择
  @State provinces: Province[] = buildProvinces();
  @State provIdx: number = 0;
  @State cityIdx: number = 0;
  @State provOptions: SelectOption[] = [];
  @State cityOptions: SelectOption[] = [];

  aboutToAppear(): void {
    // 省份选项
    for (const p of this.provinces) {
      const opt: SelectOption = { value: p.name };
      this.provOptions.push(opt);
    }
    this.initWithMemory();
  }

  // 特色功能：读取上次选择的城市并自动查询
  private async initWithMemory() {
    try {
      const ctx = getContext(this) as common.UIAbilityContext;
      const prefs: preferences.Preferences = await preferences.getPreferences(ctx, STORE_NAME);
      const p: number = prefs.getSync('provIdx', 0) as number;
      const c: number = prefs.getSync('cityIdx', 0) as number;
      this.provIdx = Math.min(Math.max(p, 0), this.provinces.length - 1);
      const cities: CityCoord[] = this.provinces[this.provIdx].cities;
      this.cityIdx = Math.min(Math.max(c, 0), cities.length - 1);
    } catch (e) {
      this.provIdx = 0;
      this.cityIdx = 0;
    }
    this.refreshCityOptions();
    this.loadWeather();
  }

  private refreshCityOptions() {
    this.cityOptions = [];
    for (const c of this.provinces[this.provIdx].cities) {
      const opt: SelectOption = { value: c.name };
      this.cityOptions.push(opt);
    }
  }

  // 查询天气：UI 只与服务层交互
  private async loadWeather() {
    this.pageState = 'loading';

    const netOk: boolean = await WeatherService.checkNetwork();
    if (!netOk) {
      this.errMsg = '当前无网络连接\n请检查网络设置后重试';
      this.pageState = 'error';
      return;
    }

    const city: CityCoord = this.provinces[this.provIdx].cities[this.cityIdx];
    const result: WeatherResult = await WeatherService.fetchWeather(city.lat, city.lon);
    if (result.success && result.current !== null) {
      this.cur = result.current;
      this.daily = result.daily;
      this.pageState = 'success';
      this.saveSelection();
    } else {
      this.errMsg = result.errMsg;
      this.pageState = 'error';
    }
  }

  // 特色功能：成功查询后记住省市选择，下次进入自动加载
  private async saveSelection() {
    try {
      const ctx = getContext(this) as common.UIAbilityContext;
      const prefs: preferences.Preferences = await preferences.getPreferences(ctx, STORE_NAME);
      prefs.putSync('provIdx', this.provIdx);
      prefs.putSync('cityIdx', this.cityIdx);
      await prefs.flush();
    } catch (e) {
      // 存储失败不影响主流程
    }
  }

  // 生活提示（依据实时温度）
  private lifeSuggestion(): string {
    const t: number = this.cur.temperature;
    if (t <= 0) {
      return '天气寒冷，注意防寒保暖 ❄️';
    }
    if (t <= 10) {
      return '气温较低，建议添加衣物 🧥';
    }
    if (t >= 32) {
      return '天气炎热，注意防暑降温 🥵';
    }
    if (t >= 26) {
      return '气温偏高，适合轻薄衣物 👕';
    }
    return '温度舒适，适合户外活动 😊';
  }

  build() {
    Column() {
      // ============ 顶部渐变标题栏 ============
      Stack({ alignContent: Alignment.Start }) {
        Column({ space: 4 }) {
          Text('天气预报')
            .fontSize(22).fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
          Text('WEATHER FORECAST')
            .fontSize(10).fontColor('#CCDDFF').letterSpacing(2)
        }
        .width('100%')
        .padding({ top: 52, bottom: 26 })
        .alignItems(HorizontalAlign.Center)
        .linearGradient({
          angle: 135,
          colors: [['#1B7FD4', 0], ['#4FB3E8', 1]]
        })

        Row({ space: 4 }) {
          Text('‹').fontSize(20).fontColor('#FFFFFF')
          Text('返回').fontSize(15).fontColor('#FFFFFF')
        }
        .padding({ left: 12, right: 14, top: 8, bottom: 8 })
        .margin({ left: 8, top: 44 })
        .borderRadius(18)
        .backgroundColor('rgba(255,255,255,0.22)')
        .onClick(() => {
          router.back();
        })
      }
      .width('100%')

      // ============ 省-市选择器 ============
      Row({ space: 10 }) {
        Select(this.provOptions)
          .selected(this.provIdx)
          .fontColor('#1A1A1A').font({ size: 14 })
          .backgroundColor('#FFFFFF')
          .borderRadius(12)
          .layoutWeight(1)
          .onSelect((index: number) => {
            if (index !== this.provIdx) {
              this.provIdx = index;
              this.cityIdx = 0;
              this.refreshCityOptions();
              this.loadWeather();
            }
          })
        Select(this.cityOptions)
          .selected(this.cityIdx)
          .fontColor('#1A1A1A').font({ size: 14 })
          .backgroundColor('#FFFFFF')
          .borderRadius(12)
          .layoutWeight(1)
          .onSelect((index: number) => {
            if (index !== this.cityIdx) {
              this.cityIdx = index;
              this.loadWeather();
            }
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 14 })

      // ============ 内容区：三态 ============
      if (this.pageState === 'loading') {
        this.loadingView()
      } else if (this.pageState === 'error') {
        this.errorView()
      } else {
        this.successView()
      }
    }
    .width('100%').height('100%')
    .backgroundColor('#EEF1F6')
  }

  // ============ 加载中 ============
  @Builder
  loadingView() {
    Column({ space: 16 }) {
      LoadingProgress().width(48).height(48).color('#1B7FD4')
      Text('正在获取天气数据...').fontSize(14).fontColor('#888888')
    }
    .width('100%').layoutWeight(1)
    .justifyContent(FlexAlign.Center)
  }

  // ============ 失败 / 无网络：提示 + 重试 ============
  @Builder
  errorView() {
    Column({ space: 18 }) {
      Text('📡').fontSize(56)
      Text(this.errMsg)
        .fontSize(15).fontColor('#666666')
        .textAlign(TextAlign.Center).lineHeight(24)
      Button('重试', { type: ButtonType.Capsule })
        .width(160).height(42)
        .fontSize(16).fontWeight(FontWeight.Medium)
        .backgroundColor('#1B7FD4')
        .onClick(() => {
          this.loadWeather();
        })
    }
    .width('100%').layoutWeight(1)
    .justifyContent(FlexAlign.Center)
  }

  // ============ 成功：实时天气 + 未来预报 ============
  @Builder
  successView() {
    Scroll() {
      Column() {
        // 实时天气大卡
        Column({ space: 6 }) {
          Text(this.provinces[this.provIdx].cities[this.cityIdx].name)
            .fontSize(16).fontColor('#666666')
          Text(WeatherText.icon(this.cur.weatherCode))
            .fontSize(64)
          Text(`${Math.round(this.cur.temperature)}°`)
            .fontSize(64).fontWeight(FontWeight.Bold).fontColor('#1A1A1A')
          Text(WeatherText.of(this.cur.weatherCode))
            .fontSize(17).fontColor('#444444')

          // 湿度 / 风向风力 / 体感
          Row() {
            this.metricCell('湿度', `${Math.round(this.cur.humidity)}%`)
            Column().width(1).height(28).backgroundColor('#E8E8E8')
            this.metricCell('风力', WindHelper.directionText(this.cur.windDirDeg) + ' ' + WindHelper.beaufort(this.cur.windSpeed))
            Column().width(1).height(28).backgroundColor('#E8E8E8')
            this.metricCell('体感', `${Math.round(this.cur.feelsLike)}°`)
          }
          .width('100%')
          .padding({ top: 14 })

          // 生活提示
          Text(this.lifeSuggestion())
            .fontSize(12).fontColor('#1B7FD4')
            .padding({ left: 12, right: 12, top: 6, bottom: 6 })
            .borderRadius(12)
            .backgroundColor('#E5F3FB')
        }
        .width('100%')
        .padding(20)
        .margin({ left: 16, right: 16, top: 14 })
        .borderRadius(20)
        .backgroundColor('#FFFFFF')
        .shadow({ radius: 14, color: '#14000000', offsetX: 0, offsetY: 5 })

        // 未来 5 天预报
        Column({ space: 12 }) {
          Row({ space: 8 }) {
            Column().width(4).height(16).borderRadius(2).backgroundColor('#1B7FD4')
            Text('未来 5 天预报').fontSize(15).fontWeight(FontWeight.Bold).fontColor('#1A1A1A')
          }
          .width('100%')

          Scroll() {
            Row({ space: 10 }) {
              ForEach(this.daily, (item: DailyItem) => {
                this.forecastCard(item)
              }, (item: DailyItem) => item.date)
            }
          }
          .scrollable(ScrollDirection.Horizontal)
          .scrollBar(BarState.Off)
          .width('100%')
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 18 })

        Column().height(24)
      }
      .width('100%')
    }
    .width('100%').layoutWeight(1)
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
  }

  // 实时天气指标格
  @Builder
  metricCell(label: string, value: string) {
    Column({ space: 5 }) {
      Text(label).fontSize(11).fontColor('#999999')
      Text(value)
        .fontSize(13).fontWeight(FontWeight.Medium).fontColor('#333333')
        .maxLines(1)
    }
    .layoutWeight(1).alignItems(HorizontalAlign.Center)
  }

  // 单日预报卡片
  @Builder
  forecastCard(item: DailyItem) {
    Column({ space: 7 }) {
      Text(item.week).fontSize(13).fontWeight(FontWeight.Medium).fontColor('#333333')
      Text(item.showDate).fontSize(11).fontColor('#AAAAAA')
      Text(WeatherText.icon(item.weatherCode)).fontSize(30)
      Text(WeatherText.of(item.weatherCode)).fontSize(11).fontColor('#777777').maxLines(1)
      Text(`${Math.round(item.maxT)}° / ${Math.round(item.minT)}°`)
        .fontSize(13).fontColor('#1A1A1A')
    }
    .width(92)
    .padding({ top: 14, bottom: 14 })
    .borderRadius(16)
    .backgroundColor('#FFFFFF')
    .shadow({ radius: 10, color: '#0F000000', offsetX: 0, offsetY: 4 })
  }
}
