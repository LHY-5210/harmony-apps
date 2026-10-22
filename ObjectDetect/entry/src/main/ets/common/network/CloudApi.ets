import { HttpResp, HttpClient } from './HttpClient';
import { AuthService } from './AuthService';
import { DetectionBox } from '../../model/Types';
import { DetectRecord, RecordStore } from '../../model/RecordStore';

export class CloudItem {
  record_id: string = '';
  device_id: string = '';
  created_at: number = 0;
  summary: string = '';
  labels: string = '';
  boxes: string = '';
  img_w: number = 0;
  img_h: number = 0;
  uploaded_at: number = 0;
}

export class RecordPage {
  total: number = 0;
  page: number = 1;
  pageSize: number = 20;
  items: CloudItem[] = [];
}

export class CategoryStat {
  label: string = '';
  count: number = 0;
}

export class StatsResult {
  total: number = 0;
  categories: CategoryStat[] = [];
}

export class ModelInfo {
  version: string = '';
  size: number = 0;
  sha256: string = '';
  url: string = '';
}

class UploadReq {
  recordId: string = '';
  createdAt: number = 0;
  summary: string = '';
  labels: string[] = [];
  boxes: DetectionBox[] = [];
  imgW: number = 0;
  imgH: number = 0;
}

export class CloudApi {
  // 带鉴权的请求：401 时清缓存、重新换 token 后重试一次
  private static async request(method: 'GET' | 'POST' | 'DELETE', path: string,
    body: string): Promise<HttpResp> {
    let token: string = await AuthService.ensureToken();
    let res: HttpResp = await HttpClient.send(method, path, body, token);
    if (res.code === 401) {
      AuthService.invalidate();
      token = await AuthService.ensureToken();
      res = await HttpClient.send(method, path, body, token);
    }
    return res;
  }

  static async upload(rec: DetectRecord): Promise<boolean> {
    const req: UploadReq = new UploadReq();
    req.recordId = rec.recordId;
    req.createdAt = rec.createdAt;
    req.summary = rec.summary;
    req.labels = rec.labels.length > 0 ? rec.labels.split(',') : [];
    req.boxes = RecordStore.boxesOf(rec);
    req.imgW = rec.imgW;
    req.imgH = rec.imgH;
    const res: HttpResp = await CloudApi.request('POST', '/api/records', JSON.stringify(req));
    return res.code === 200;
  }

  static async queryRecords(fromTime: number, label: string, page: number,
    pageSize: number): Promise<RecordPage> {
    let path: string = `/api/records?page=${page}&pageSize=${pageSize}`;
    if (fromTime > 0) {
      path += `&from=${fromTime}`;
    }
    if (label.length > 0) {
      path += `&label=${encodeURIComponent(label)}`;
    }
    const res: HttpResp = await CloudApi.request('GET', path, '');
    if (res.code !== 200) {
      throw new Error(`query failed ${res.code}`);
    }
    return JSON.parse(res.body) as RecordPage;
  }

  static async stats(): Promise<StatsResult> {
    const res: HttpResp = await CloudApi.request('GET', '/api/stats', '');
    if (res.code !== 200) {
      throw new Error(`stats failed ${res.code}`);
    }
    return JSON.parse(res.body) as StatsResult;
  }

  static async modelLatest(): Promise<ModelInfo> {
    const res: HttpResp = await CloudApi.request('GET', '/api/model/latest', '');
    if (res.code !== 200) {
      throw new Error(`model latest failed ${res.code}`);
    }
    return JSON.parse(res.body) as ModelInfo;
  }

  // 模型下载到指定路径，返回字节数；失败抛异常
  static async downloadModel(version: string, dstPath: string): Promise<number> {
    let token: string = await AuthService.ensureToken();
    let n: number = await HttpClient.download(`/api/model/download/${version}`, token, dstPath);
    if (n === -1) {
      AuthService.invalidate();
      token = await AuthService.ensureToken();
      n = await HttpClient.download(`/api/model/download/${version}`, token, dstPath);
    }
    if (n < 0) {
      throw new Error('model download failed');
    }
    return n;
  }
}
