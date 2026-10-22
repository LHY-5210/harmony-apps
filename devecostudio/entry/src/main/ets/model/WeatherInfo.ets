// 天气数据模型：实时天气、每日预报、WMO 天气码映射、风力风向换算
// 与 UI、网络层解耦，仅承载数据与纯函数换算

// 实时天气
export class CurrentWeather {
  temperature: number = 0;      // 摄氏度
  feelsLike: number = 0;        // 体感温度
  humidity: number = 0;         // 相对湿度 %
  weatherCode: number = 0;      // WMO 天气代码
  windSpeed: number = 0;        // 米/秒
  windDirDeg: number = 0;       // 风向角度 0-359
}

// 单日预报
export class DailyItem {
  date: string = '';            // 原始日期 yyyy-MM-dd
  showDate: string = '';        // 展示用 MM/dd
  week: string = '';            // 周X / 今天
  weatherCode: number = 0;
  maxT: number = 0;
  minT: number = 0;
}

// 天气查询结果：UI 只需判断 success 并读取数据或错误提示
export class WeatherResult {
  success: boolean = false;
  errMsg: string = '';
  current: CurrentWeather | null = null;
  daily: DailyItem[] = [];
}

// WMO 天气代码 → 中文描述
export class WeatherText {
  static of(code: number): string {
    if (code === 0) {
      return '晴';
    }
    if (code === 1) {
      return '晴间多云';
    }
    if (code === 2) {
      return '多云';
    }
    if (code === 3) {
      return '阴';
    }
    if (code === 45 || code === 48) {
      return '雾';
    }
    if (code >= 51 && code <= 57) {
      return '毛毛雨';
    }
    if (code === 61 || code === 80) {
      return '小雨';
    }
    if (code === 63 || code === 81) {
      return '中雨';
    }
    if (code === 65 || code === 82) {
      return '大雨';
    }
    if (code === 66 || code === 67) {
      return '冻雨';
    }
    if (code === 71 || code === 85) {
      return '小雪';
    }
    if (code === 73 || code === 86) {
      return '中雪';
    }
    if (code === 75 || code === 77) {
      return '大雪';
    }
    if (code >= 95) {
      return '雷阵雨';
    }
    return '未知';
  }

  // 天气图标（emoji，无需资源文件）
  static icon(code: number): string {
    if (code === 0) {
      return '☀️';
    }
    if (code >= 1 && code <= 2) {
      return '⛅';
    }
    if (code === 3) {
      return '☁️';
    }
    if (code === 45 || code === 48) {
      return '🌫️';
    }
    if (code >= 51 && code <= 57) {
      return '🌦️';
    }
    if ((code >= 61 && code <= 67) || (code >= 80 && code <= 82)) {
      return '🌧️';
    }
    if ((code >= 71 && code <= 77) || code === 85 || code === 86) {
      return '❄️';
    }
    if (code >= 95) {
      return '⛈️';
    }
    return '🌍';
  }
}

// 风力风向换算（纯函数）
export class WindHelper {
  // 风向角度 → 十六方位中文
  static directionText(deg: number): string {
    const dirs: string[] = ['北', '东北', '东', '东南', '南', '西南', '西', '西北'];
    const idx: number = Math.round(deg / 45) % 8;
    return dirs[idx] + '风';
  }

  // 米/秒 → 蒲福风级
  static beaufort(speedMs: number): string {
    const limits: number[] = [0.3, 1.6, 3.4, 5.5, 8.0, 10.8, 13.9, 17.2, 20.8, 24.5, 28.5, 32.7];
    let level: number = 12;
    for (let i = 0; i < limits.length; i++) {
      if (speedMs < limits[i]) {
        level = i;
        break;
      }
    }
    return level + ' 级';
  }
}
