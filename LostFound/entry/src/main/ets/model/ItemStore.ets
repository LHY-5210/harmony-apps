import { relationalStore } from '@kit.ArkData';
import { Item } from '../model/Types';

// 本地 RDB 缓存：离线可浏览物品列表与"我的发布"
export class ItemStore {
  private static store: relationalStore.RdbStore | null = null;
  private static readonly STORE_CONFIG: relationalStore.StoreConfig = {
    name: 'lostfound.db',
    securityLevel: relationalStore.SecurityLevel.S1
  };

  static async getStore(): Promise<relationalStore.RdbStore> {
    if (ItemStore.store === null) {
      const s: relationalStore.RdbStore = await relationalStore.getRdbStore(getContext(), ItemStore.STORE_CONFIG);
      await s.executeSql(
        `CREATE TABLE IF NOT EXISTS items (
          itemId TEXT PRIMARY KEY, userId INTEGER, type TEXT, category TEXT, color TEXT,
          location TEXT, eventTime REAL, description TEXT, ocrText TEXT, imageUrl TEXT,
          credentialQuestion TEXT, credentialAnswer TEXT, status TEXT, createdAt REAL,
          isMine INTEGER DEFAULT 0
        )`
      );
      ItemStore.store = s;
    }
    return ItemStore.store as relationalStore.RdbStore;
  }

  static async upsert(item: Item, isMine: boolean): Promise<void> {
    const store = await ItemStore.getStore();
    const bucket: relationalStore.ValuesBucket = {
      itemId: item.itemId,
      userId: item.userId,
      type: item.type,
      category: item.category,
      color: item.color,
      location: item.location,
      eventTime: item.eventTime,
      description: item.description,
      ocrText: item.ocrText,
      imageUrl: item.imageUrl,
      credentialQuestion: item.credentialQuestion,
      credentialAnswer: item.credentialAnswer,
      status: item.status,
      createdAt: item.createdAt,
      isMine: isMine ? 1 : 0
    };
    await store.insert('items', bucket, relationalStore.ConflictResolution.ON_CONFLICT_REPLACE);
  }

  static async upsertAll(items: Item[], isMine: boolean): Promise<void> {
    const store = await ItemStore.getStore();
    for (const it of items) {
      const bucket: relationalStore.ValuesBucket = {
        itemId: it.itemId, userId: it.userId, type: it.type, category: it.category,
        color: it.color, location: it.location, eventTime: it.eventTime, description: it.description,
        ocrText: it.ocrText, imageUrl: it.imageUrl, credentialQuestion: it.credentialQuestion,
        credentialAnswer: it.credentialAnswer, status: it.status, createdAt: it.createdAt,
        isMine: isMine ? 1 : 0
      };
      await store.insert('items', bucket, relationalStore.ConflictResolution.ON_CONFLICT_REPLACE);
    }
  }

  static async listAll(): Promise<Item[]> {
    const store = await ItemStore.getStore();
    const rs = await store.querySql('SELECT * FROM items ORDER BY createdAt DESC');
    return ItemStore.readAll(rs);
  }

  static async listMine(): Promise<Item[]> {
    const store = await ItemStore.getStore();
    const rs = await store.querySql('SELECT * FROM items WHERE isMine=1 ORDER BY createdAt DESC');
    return ItemStore.readAll(rs);
  }

  static async get(itemId: string): Promise<Item | null> {
    const store = await ItemStore.getStore();
    const rs = await store.querySql('SELECT * FROM items WHERE itemId=?', [itemId]);
    const list = ItemStore.readAll(rs);
    return list.length > 0 ? list[0] : null;
  }

  private static readAll(rs: relationalStore.ResultSet): Item[] {
    const items: Item[] = [];
    if (rs.rowCount === 0) {
      return items;
    }
    rs.goToFirstRow();
    do {
      const it: Item = new Item();
      it.itemId = rs.getString(rs.getColumnIndex('itemId'));
      it.userId = rs.getLong(rs.getColumnIndex('userId'));
      it.type = rs.getString(rs.getColumnIndex('type')) as 'lost' | 'found';
      it.category = rs.getString(rs.getColumnIndex('category'));
      it.color = rs.getString(rs.getColumnIndex('color'));
      it.location = rs.getString(rs.getColumnIndex('location'));
      it.eventTime = rs.getDouble(rs.getColumnIndex('eventTime'));
      it.description = rs.getString(rs.getColumnIndex('description'));
      it.ocrText = rs.getString(rs.getColumnIndex('ocrText'));
      it.imageUrl = rs.getString(rs.getColumnIndex('imageUrl'));
      it.status = rs.getString(rs.getColumnIndex('status'));
      it.createdAt = rs.getDouble(rs.getColumnIndex('createdAt'));
      items.push(it);
    } while (rs.goToNextRow());
    return items;
  }
}
