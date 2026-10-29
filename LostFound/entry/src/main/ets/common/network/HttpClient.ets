import { http } from '@kit.NetworkKit';
import { AuthService } from './AuthService';

export type HttpMethod = 'GET' | 'POST' | 'DELETE';

interface ErrorBody {
  detail: string;
}

// 统一的 HTTP 出口：自动附带 JWT、JSON 收发；body 为 JSON 字符串
export class HttpClient {
  static readonly BASE: string = 'http://10.0.2.2:8000';
  private static readonly TIMEOUT: number = 15000;

  private static methodOf(m: HttpMethod): http.RequestMethod {
    if (m === 'POST') {
      return http.RequestMethod.POST;
    }
    if (m === 'DELETE') {
      return http.RequestMethod.DELETE;
    }
    return http.RequestMethod.GET;
  }

  static async send<T extends Object>(method: HttpMethod, path: string, body?: string): Promise<T> {
    const req: http.HttpRequest = http.createHttp();
    try {
      const token: string = await AuthService.getToken();
      const header: Record<string, string> = { 'Content-Type': 'application/json' };
      if (token.length > 0) {
        header['Authorization'] = 'Bearer ' + token;
      }
      const opts: http.HttpRequestOptions = {
        method: HttpClient.methodOf(method),
        header: header,
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: HttpClient.TIMEOUT,
        readTimeout: HttpClient.TIMEOUT
      };
      if (body && body.length > 0) {
        opts.extraData = body;
      }
      const r: http.HttpResponse = await req.request(HttpClient.BASE + path, opts);
      const text: string = typeof r.result === 'string' ? r.result : '';
      if (r.responseCode < 200 || r.responseCode >= 300) {
        let msg: string = 'HTTP ' + r.responseCode;
        try {
          const obj: ErrorBody = JSON.parse(text) as ErrorBody;
          if (obj.detail.length > 0) {
            msg = obj.detail;
          }
        } catch (e) {
          // 忽略
        }
        if (r.responseCode === 401) {
          await AuthService.logout();
        }
        throw new Error(msg);
      }
      if (!text) {
        return new Object() as T;
      }
      return JSON.parse(text) as T;
    } finally {
      req.destroy();
    }
  }

  static async get<T extends Object>(path: string): Promise<T> {
    return HttpClient.send<T>('GET', path);
  }
}
