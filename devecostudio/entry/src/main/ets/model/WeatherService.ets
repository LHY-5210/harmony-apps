// 天气网络服务：独立封装网络请求与数据解析，UI 层只调用 fetchWeather 拿 WeatherResult
// 数据源：Open-Meteo 免费气象接口（无需 API Key）
// 错误处理：无网络 / 请求超时 / 网络失败 / 服务器错误 / 数据异常 均映射为友好中文提示
import { http, connection } from '@kit.NetworkKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { CurrentWeather, DailyItem, WeatherResult } from './WeatherInfo';

const BASE_URL: string = 'https://api.open-meteo.com/v1/forecast';
const TIMEOUT_MS: number = 10000;

export class WeatherService {
  // 检查设备是否有可用网络（提前拦截，给出最友好的无网提示）
  static async checkNetwork(): Promise<boolean> {
    try {
      return await connection.hasDefaultNet();
    } catch (e) {
      return false;
    }
  }

  // 按经纬度查询实时天气与未来 5 天预报
  static async fetchWeather(lat: number, lon: number): Promise<WeatherResult> {
    const result: WeatherResult = new WeatherResult();
    const url: string =
      `${BASE_URL}?latitude=${lat}&longitude=${lon}` +
      `&current=temperature_2m,relative_humidity_2m,apparent_temperature,weather_code,wind_speed_10m,wind_direction_10m` +
      `&daily=weather_code,temperature_2m_max,temperature_2m_min` +
      `&timezone=Asia%2FShanghai&forecast_days=5&wind_speed_unit=ms`;

    const req: http.HttpRequest = http.createHttp();
    try {
      const options: http.HttpRequestOptions = {
        method: http.RequestMethod.GET,
        connectTimeout: TIMEOUT_MS,
        readTimeout: TIMEOUT_MS,
        expectDataType: http.HttpDataType.STRING
      };
      const res: http.HttpResponse = await req.request(url, options);
      if (res.responseCode !== 200) {
        result.errMsg = '天气服务暂时不可用，请稍后重试';
        return result;
      }
      return WeatherService.parse(res.result as string);
    } catch (e) {
      const err = e as BusinessError;
      if (err.code === 2300028) {
        result.errMsg = '请求超时，请检查网络后重试';
      } else {
        result.errMsg = '网络连接失败，请检查网络设置后重试';
      }
      return result;
    } finally {
      req.destroy();
    }
  }

  // 解析接口返回的 JSON 为数据模型；解析失败统一返回数据异常提示
  private static parse(text: string): WeatherResult {
    const result: WeatherResult = new WeatherResult();
    try {
      const root: Record<string, Object> = JSON.parse(text) as Record<string, Object>;
      const cur: Record<string, Object> = root['current'] as Record<string, Object>;

      const current: CurrentWeather = new CurrentWeather();
      current.temperature = cur['temperature_2m'] as number;
      current.feelsLike = cur['apparent_temperature'] as number;
      current.humidity = cur['relative_humidity_2m'] as number;
      current.weatherCode = cur['weather_code'] as number;
      current.windSpeed = cur['wind_speed_10m'] as number;
      current.windDirDeg = cur['wind_direction_10m'] as number;
      result.current = current;

      const dailyRaw: Record<string, Object> = root['daily'] as Record<string, Object>;
      const times: Array<string> = dailyRaw['time'] as Array<string>;
      const codes: Array<number> = dailyRaw['weather_code'] as Array<number>;
      const maxs: Array<number> = dailyRaw['temperature_2m_max'] as Array<number>;
      const mins: Array<number> = dailyRaw['temperature_2m_min'] as Array<number>;

      const weekNames: string[] = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'];
      const daily: DailyItem[] = [];
      for (let i = 0; i < times.length; i++) {
        const item: DailyItem = new DailyItem();
        item.date = times[i];
        item.showDate = times[i].substring(5).replace('-', '/');
        item.week = i === 0 ? '今天' : weekNames[new Date(times[i]).getDay()];
        item.weatherCode = codes[i];
        item.maxT = maxs[i];
        item.minT = mins[i];
        daily.push(item);
      }
      result.daily = daily;

      result.success = true;
      return result;
    } catch (e) {
      result.success = false;
      result.errMsg = '天气数据异常，请重试';
      return result;
    }
  }
}
