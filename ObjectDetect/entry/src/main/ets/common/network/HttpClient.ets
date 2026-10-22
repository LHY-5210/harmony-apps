import { http } from '@kit.NetworkKit';
import { fileIo } from '@kit.CoreFileKit';

export type HttpMethod = 'GET' | 'POST' | 'DELETE';

export class HttpResp {
  code: number = 0;
  body: string = '';
  error: string = '';
}

// 统一的 HTTP 出口：JSON 收发 + 二进制下载
export class HttpClient {
  // 模拟器访问宿主机回环地址
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

  static async send(method: HttpMethod, path: string, body: string, token: string): Promise<HttpResp> {
    const resp: HttpResp = new HttpResp();
    const req: http.HttpRequest = http.createHttp();
    try {
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
      if (body.length > 0) {
        opts.extraData = body;
      }
      const r: http.HttpResponse = await req.request(HttpClient.BASE + path, opts);
      resp.code = r.responseCode;
      resp.body = typeof r.result === 'string' ? r.result : '';
    } catch (e) {
      resp.error = JSON.stringify(e);
    } finally {
      req.destroy();
    }
    return resp;
  }

  // 下载二进制到指定路径，返回字节数；HTTP 非 200 返回 -1
  static async download(path: string, token: string, dstPath: string): Promise<number> {
    const req: http.HttpRequest = http.createHttp();
    try {
      const header: Record<string, string> = {};
      if (token.length > 0) {
        header['Authorization'] = 'Bearer ' + token;
      }
      const opts: http.HttpRequestOptions = {
        method: http.RequestMethod.GET,
        header: header,
        expectDataType: http.HttpDataType.ARRAY_BUFFER,
        connectTimeout: 30000,
        readTimeout: 300000
      };
      const r: http.HttpResponse = await req.request(HttpClient.BASE + path, opts);
      if (r.responseCode !== 200) {
        return -1;
      }
      const data: ArrayBuffer = r.result as ArrayBuffer;
      const file: fileIo.File = fileIo.openSync(dstPath,
        fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
      fileIo.writeSync(file.fd, data);
      fileIo.closeSync(file.fd);
      return data.byteLength;
    } finally {
      req.destroy();
    }
  }
}
