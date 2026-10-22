import { relationalStore } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { DetectionBox } from './Types';

const SQL_CREATE: string = `CREATE TABLE IF NOT EXISTS records (
  record_id TEXT PRIMARY KEY,
  created_at INTEGER NOT NULL,
  thumb_path TEXT,
  img_w INTEGER,
  img_h INTEGER,
  summary TEXT,
  labels TEXT,
  boxes_json TEXT,
  synced INTEGER DEFAULT 0
)`;

export class DetectRecord {
  recordId: string = '';
  createdAt: number = 0;
  thumbPath: string = '';
  imgW: number = 0;
  imgH: number = 0;
  summary: string = '';
  labels: string = '';
  boxesJson: string = '';
  synced: boolean = false;
}

export class RecordStore {
  private static store: relationalStore.RdbStore | null = null;

  static async init(ctx: common.Context): Promise<void> {
    if (RecordStore.store !== null) {
      return;
    }
    const config: relationalStore.StoreConfig = {
      name: 'objectdetect.db',
      securityLevel: relationalStore.SecurityLevel.S1
    };
    const st: relationalStore.RdbStore = await relationalStore.getRdbStore(ctx, config);
    await st.executeSql(SQL_CREATE);
    RecordStore.store = st;
  }

  private static db(): relationalStore.RdbStore {
    if (RecordStore.store === null) {
      throw new Error('RecordStore not initialized');
    }
    return RecordStore.store;
  }

  static async insert(rec: DetectRecord): Promise<void> {
    const vb: relationalStore.ValuesBucket = {
      'record_id': rec.recordId,
      'created_at': rec.createdAt,
      'thumb_path': rec.thumbPath,
      'img_w': rec.imgW,
      'img_h': rec.imgH,
      'summary': rec.summary,
      'labels': rec.labels,
      'boxes_json': rec.boxesJson,
      'synced': rec.synced ? 1 : 0
    };
    await RecordStore.db().insert('records', vb);
  }

  // fromTime 为 0 表示不限时间；label 为空表示不限类别
  static async query(fromTime: number, label: string): Promise<DetectRecord[]> {
    const pred: relationalStore.RdbPredicates = new relationalStore.RdbPredicates('records');
    pred.orderByDesc('created_at');
    if (fromTime > 0) {
      pred.greaterThanOrEqualTo('created_at', fromTime);
    }
    if (label.length > 0) {
      pred.like('labels', `%${label}%`);
    }
    const rs: relationalStore.ResultSet = await RecordStore.db().query(pred,
      ['record_id', 'created_at', 'thumb_path', 'img_w', 'img_h', 'summary', 'labels', 'boxes_json', 'synced']);
    const list: DetectRecord[] = [];
    while (rs.goToNextRow()) {
      const r: DetectRecord = new DetectRecord();
      r.recordId = rs.getString(rs.getColumnIndex('record_id'));
      r.createdAt = rs.getLong(rs.getColumnIndex('created_at'));
      r.thumbPath = rs.getString(rs.getColumnIndex('thumb_path'));
      r.imgW = rs.getLong(rs.getColumnIndex('img_w'));
      r.imgH = rs.getLong(rs.getColumnIndex('img_h'));
      r.summary = rs.getString(rs.getColumnIndex('summary'));
      r.labels = rs.getString(rs.getColumnIndex('labels'));
      r.boxesJson = rs.getString(rs.getColumnIndex('boxes_json'));
      r.synced = rs.getLong(rs.getColumnIndex('synced')) === 1;
      list.push(r);
    }
    rs.close();
    return list;
  }

  static async deleteById(recordId: string): Promise<void> {
    const pred: relationalStore.RdbPredicates = new relationalStore.RdbPredicates('records');
    pred.equalTo('record_id', recordId);
    await RecordStore.db().delete(pred);
  }

  // 待同步队列（按时间正序，先传早的）
  static async queryUnsynced(limit: number): Promise<DetectRecord[]> {
    const pred: relationalStore.RdbPredicates = new relationalStore.RdbPredicates('records');
    pred.equalTo('synced', 0).orderByAsc('created_at').limitAs(limit);
    const rs: relationalStore.ResultSet = await RecordStore.db().query(pred,
      ['record_id', 'created_at', 'thumb_path', 'img_w', 'img_h', 'summary', 'labels', 'boxes_json', 'synced']);
    const list: DetectRecord[] = [];
    while (rs.goToNextRow()) {
      const r: DetectRecord = new DetectRecord();
      r.recordId = rs.getString(rs.getColumnIndex('record_id'));
      r.createdAt = rs.getLong(rs.getColumnIndex('created_at'));
      r.thumbPath = rs.getString(rs.getColumnIndex('thumb_path'));
      r.imgW = rs.getLong(rs.getColumnIndex('img_w'));
      r.imgH = rs.getLong(rs.getColumnIndex('img_h'));
      r.summary = rs.getString(rs.getColumnIndex('summary'));
      r.labels = rs.getString(rs.getColumnIndex('labels'));
      r.boxesJson = rs.getString(rs.getColumnIndex('boxes_json'));
      r.synced = false;
      list.push(r);
    }
    rs.close();
    return list;
  }

  static async markSynced(ids: string[]): Promise<void> {
    if (ids.length === 0) {
      return;
    }
    const pred: relationalStore.RdbPredicates = new relationalStore.RdbPredicates('records');
    pred.in('record_id', ids);
    const vb: relationalStore.ValuesBucket = { 'synced': 1 };
    await RecordStore.db().update(vb, pred);
  }

  static pendingCount(records: DetectRecord[]): number {
    let n: number = 0;
    for (let i = 0; i < records.length; i++) {
      if (!records[i].synced) { n = n + 1; }
    }
    return n;
  }

  static async count(): Promise<number> {
    const pred: relationalStore.RdbPredicates = new relationalStore.RdbPredicates('records');
    const rs: relationalStore.ResultSet = await RecordStore.db().query(pred, ['record_id']);
    const n: number = rs.rowCount;
    rs.close();
    return n;
  }

  static boxesOf(rec: DetectRecord): DetectionBox[] {
    try {
      return JSON.parse(rec.boxesJson) as DetectionBox[];
    } catch (e) {
      return [];
    }
  }
}
