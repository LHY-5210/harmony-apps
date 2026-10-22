import { common } from '@kit.AbilityKit';
import { relationalStore } from '@kit.ArkData';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG = 'FavoriteStore';
const DB_NAME = 'human_atlas.db';

const CREATE_FAVORITE = `CREATE TABLE IF NOT EXISTS favorite (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  structure_id TEXT NOT NULL,
  name TEXT NOT NULL,
  system TEXT DEFAULT '',
  create_time INTEGER NOT NULL,
  UNIQUE(structure_id) ON CONFLICT REPLACE
)`;

const CREATE_HISTORY = `CREATE TABLE IF NOT EXISTS history (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  structure_id TEXT NOT NULL,
  name TEXT NOT NULL,
  system TEXT DEFAULT '',
  visit_time INTEGER NOT NULL,
  UNIQUE(structure_id) ON CONFLICT REPLACE
)`;

const CREATE_NOTE = `CREATE TABLE IF NOT EXISTS note (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  structure_id TEXT NOT NULL,
  title TEXT DEFAULT '',
  content TEXT DEFAULT '',
  update_time INTEGER NOT NULL
)`;

export interface FavoriteItem {
  id: number;
  structureId: string;
  name: string;
  system: string;
  createTime: number;
}

export interface HistoryItem {
  id: number;
  structureId: string;
  name: string;
  system: string;
  visitTime: number;
}

export interface NoteItem {
  id: number;
  structureId: string;
  title: string;
  content: string;
  updateTime: number;
}

export class FavoriteStore {
  private static instance: FavoriteStore | null = null;
  private ctx: common.UIAbilityContext | null = null;
  private db: relationalStore.RdbStore | null = null;

  static getInstance(): FavoriteStore {
    if (FavoriteStore.instance === null) {
      FavoriteStore.instance = new FavoriteStore();
    }
    return FavoriteStore.instance;
  }

  async init(ctx: common.UIAbilityContext): Promise<void> {
    if (this.db !== null) { return; }
    this.ctx = ctx;
    try {
      const config: relationalStore.StoreConfig = {
        name: DB_NAME,
        securityLevel: relationalStore.SecurityLevel.S1
      };
      this.db = await relationalStore.getRdbStore(ctx, config);
      await this.db.executeSql(CREATE_FAVORITE);
      await this.db.executeSql(CREATE_HISTORY);
      await this.db.executeSql(CREATE_NOTE);
      hilog.info(0x0000, TAG, 'tables ready');
    } catch (e) {
      hilog.error(0x0000, TAG, `init failed: ${JSON.stringify(e)}`);
    }
  }

  async addFavorite(structureId: string, name: string, system: string): Promise<number> {
    if (this.db === null) { return -1; }
    const bucket: relationalStore.ValuesBucket = {
      'structure_id': structureId,
      'name': name,
      'system': system,
      'create_time': Date.now()
    };
    return this.db.insert('favorite', bucket, relationalStore.ConflictResolution.ON_CONFLICT_REPLACE);
  }

  async removeFavorite(structureId: string): Promise<number> {
    if (this.db === null) { return 0; }
    const pred: relationalStore.RdbPredicates = new relationalStore.RdbPredicates('favorite');
    pred.equalTo('structure_id', structureId);
    return this.db.delete(pred);
  }

  async isFavorite(structureId: string): Promise<boolean> {
    if (this.db === null) { return false; }
    const pred: relationalStore.RdbPredicates = new relationalStore.RdbPredicates('favorite');
    pred.equalTo('structure_id', structureId);
    const rs: relationalStore.ResultSet = await this.db.query(pred);
    const has: boolean = rs.rowCount > 0;
    rs.close();
    return has;
  }

  async getFavorites(): Promise<FavoriteItem[]> {
    if (this.db === null) { return []; }
    const pred: relationalStore.RdbPredicates = new relationalStore.RdbPredicates('favorite');
    pred.orderByDesc('create_time');
    const rs: relationalStore.ResultSet = await this.db.query(pred);
    const items: FavoriteItem[] = [];
    while (rs.goToNextRow()) {
      items.push({
        id: rs.getLong(rs.getColumnIndex('id')),
        structureId: rs.getString(rs.getColumnIndex('structure_id')),
        name: rs.getString(rs.getColumnIndex('name')),
        system: rs.getString(rs.getColumnIndex('system')),
        createTime: rs.getLong(rs.getColumnIndex('create_time'))
      });
    }
    rs.close();
    return items;
  }

  async addHistory(structureId: string, name: string, system: string): Promise<void> {
    if (this.db === null) { return; }
    const bucket: relationalStore.ValuesBucket = {
      'structure_id': structureId,
      'name': name,
      'system': system,
      'visit_time': Date.now()
    };
    await this.db.insert('history', bucket, relationalStore.ConflictResolution.ON_CONFLICT_REPLACE);
  }

  async clearHistory(): Promise<number> {
    if (this.db === null) { return 0; }
    const pred: relationalStore.RdbPredicates = new relationalStore.RdbPredicates('history');
    return this.db.delete(pred);
  }

  async getHistory(): Promise<HistoryItem[]> {
    if (this.db === null) { return []; }
    const pred: relationalStore.RdbPredicates = new relationalStore.RdbPredicates('history');
    pred.orderByDesc('visit_time');
    const rs: relationalStore.ResultSet = await this.db.query(pred);
    const items: HistoryItem[] = [];
    while (rs.goToNextRow()) {
      items.push({
        id: rs.getLong(rs.getColumnIndex('id')),
        structureId: rs.getString(rs.getColumnIndex('structure_id')),
        name: rs.getString(rs.getColumnIndex('name')),
        system: rs.getString(rs.getColumnIndex('system')),
        visitTime: rs.getLong(rs.getColumnIndex('visit_time'))
      });
    }
    rs.close();
    return items;
  }

  async saveNote(structureId: string, title: string, content: string): Promise<number> {
    if (this.db === null) { return -1; }
    const bucket: relationalStore.ValuesBucket = {
      'structure_id': structureId,
      'title': title,
      'content': content,
      'update_time': Date.now()
    };
    return this.db.insert('note', bucket, relationalStore.ConflictResolution.ON_CONFLICT_REPLACE);
  }

  async getNote(structureId: string): Promise<NoteItem | null> {
    if (this.db === null) { return null; }
    const pred: relationalStore.RdbPredicates = new relationalStore.RdbPredicates('note');
    pred.equalTo('structure_id', structureId);
    const rs: relationalStore.ResultSet = await this.db.query(pred);
    let item: NoteItem | null = null;
    if (rs.goToNextRow()) {
      item = {
        id: rs.getLong(rs.getColumnIndex('id')),
        structureId: rs.getString(rs.getColumnIndex('structure_id')),
        title: rs.getString(rs.getColumnIndex('title')),
        content: rs.getString(rs.getColumnIndex('content')),
        updateTime: rs.getLong(rs.getColumnIndex('update_time'))
      };
    }
    rs.close();
    return item;
  }
}
