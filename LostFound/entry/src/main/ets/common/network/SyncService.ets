import preferences from '@ohos.data.preferences';
import { ApiService } from './ApiService';
import { Item } from '../../model/Types';
import { ItemStore } from '../../model/ItemStore';

const PREF_NAME: string = 'sync_queue';
const KEY_PENDING: string = 'pending_items';

// 数据同步服务：发布失败进待传队列，联网后自动重传；增量拉取物品列表
export class SyncService {
  private static store: preferences.Preferences | null = null;

  private static async getStore(): Promise<preferences.Preferences> {
    if (SyncService.store === null) {
      SyncService.store = await preferences.getPreferences(getContext(), PREF_NAME);
    }
    return SyncService.store;
  }

  static async enqueue(item: Item): Promise<void> {
    const store = await SyncService.getStore();
    const raw = await store.get(KEY_PENDING, '[]');
    const list: Item[] = JSON.parse(raw as string) as Item[];
    list.push(item);
    await store.put(KEY_PENDING, JSON.stringify(list));
    await store.flush();
  }

  static async pendingCount(): Promise<number> {
    const store = await SyncService.getStore();
    const raw = await store.get(KEY_PENDING, '[]');
    return (JSON.parse(raw as string) as Item[]).length;
  }

  static async flush(): Promise<number> {
    const store = await SyncService.getStore();
    const raw = await store.get(KEY_PENDING, '[]');
    const list: Item[] = JSON.parse(raw as string) as Item[];
    if (list.length === 0) {
      return 0;
    }
    const remain: Item[] = [];
    let success: number = 0;
    for (const it of list) {
      try {
        await ApiService.createItem(it);
        await ItemStore.upsert(it, true);
        success++;
      } catch (e) {
        remain.push(it);
      }
    }
    await store.put(KEY_PENDING, JSON.stringify(remain));
    await store.flush();
    return success;
  }

  static async syncDown(since: number, isMine: boolean): Promise<number> {
    try {
      const resp = await ApiService.syncItems(since);
      if (resp.items.length > 0) {
        await ItemStore.upsertAll(resp.items, isMine);
      }
      return resp.items.length;
    } catch (e) {
      return 0;
    }
  }
}
