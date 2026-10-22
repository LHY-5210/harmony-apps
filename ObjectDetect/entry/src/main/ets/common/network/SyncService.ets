import { CloudApi } from './CloudApi';
import { RecordStore, DetectRecord } from '../../model/RecordStore';

export class SyncSummary {
  total: number = 0;
  ok: number = 0;
  failed: number = 0;
  offline: boolean = false;
  message: string = '';
}

// 断网重传：本地 synced=0 的记录逐条上传，成功才标记已同步
export class SyncService {
  static async syncPending(limit: number): Promise<SyncSummary> {
    const sum: SyncSummary = new SyncSummary();
    const list: DetectRecord[] = await RecordStore.queryUnsynced(limit);
    sum.total = list.length;
    if (list.length === 0) {
      sum.message = '没有待同步记录';
      return sum;
    }
    const okIds: string[] = [];
    for (let i = 0; i < list.length; i++) {
      try {
        const success: boolean = await CloudApi.upload(list[i]);
        if (success) {
          okIds.push(list[i].recordId);
          sum.ok = sum.ok + 1;
        } else {
          sum.failed = sum.failed + 1;
        }
      } catch (e) {
        // 网络异常：保留剩余队列，下次继续
        sum.failed = sum.failed + (list.length - i);
        sum.offline = true;
        break;
      }
    }
    if (okIds.length > 0) {
      await RecordStore.markSynced(okIds);
    }
    sum.message = sum.offline
      ? `网络不可用，成功 ${sum.ok} 条，剩余 ${sum.failed} 条留在队列`
      : `同步完成：成功 ${sum.ok} 条，失败 ${sum.failed} 条`;
    return sum;
  }
}
