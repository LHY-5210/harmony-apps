// 名片数据库封装（基于 RelationalStore / SQLite）
import { relationalStore } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { CardInfo } from './CardInfo';

const CREATE_SQL: string =
  `CREATE TABLE IF NOT EXISTS card (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    company TEXT,
    title TEXT,
    phone TEXT,
    email TEXT,
    address TEXT,
    groupName TEXT,
    favorite INTEGER DEFAULT 0,
    note TEXT,
    createTime INTEGER
  )`;

export class CardDB {
  private store: relationalStore.RdbStore | undefined = undefined;

  // 初始化数据库（多页面各自调用也安全，同库名返回同一实例）
  async init(context: common.UIAbilityContext): Promise<void> {
    if (this.store !== undefined) {
      return;
    }
    const config: relationalStore.StoreConfig = {
      name: 'ecard.db',
      securityLevel: relationalStore.SecurityLevel.S1
    };
    this.store = await relationalStore.getRdbStore(context, config);
    await this.store.executeSql(CREATE_SQL);
  }

  // 结果集 -> 名片对象
  private rowToCard(rs: relationalStore.ResultSet): CardInfo {
    const c = new CardInfo();
    c.id = rs.getLong(rs.getColumnIndex('id'));
    c.name = rs.getString(rs.getColumnIndex('name'));
    c.company = rs.getString(rs.getColumnIndex('company'));
    c.title = rs.getString(rs.getColumnIndex('title'));
    c.phone = rs.getString(rs.getColumnIndex('phone'));
    c.email = rs.getString(rs.getColumnIndex('email'));
    c.address = rs.getString(rs.getColumnIndex('address'));
    c.groupName = rs.getString(rs.getColumnIndex('groupName'));
    c.favorite = rs.getLong(rs.getColumnIndex('favorite'));
    c.note = rs.getString(rs.getColumnIndex('note'));
    c.createTime = rs.getLong(rs.getColumnIndex('createTime'));
    return c;
  }

  // 组装插入/更新字段
  private fill(c: CardInfo, isAdd: boolean): relationalStore.ValuesBucket {
    const bucket: relationalStore.ValuesBucket = {
      'name': c.name,
      'company': c.company,
      'title': c.title,
      'phone': c.phone,
      'email': c.email,
      'address': c.address,
      'groupName': c.groupName,
      'favorite': c.favorite,
      'note': c.note
    };
    if (isAdd) {
      bucket['createTime'] = Date.now();
    }
    return bucket;
  }

  // 新增，返回新记录 id
  async add(c: CardInfo): Promise<number> {
    if (this.store === undefined) {
      return -1;
    }
    return await this.store.insert('card', this.fill(c, true));
  }

  // 按 id 更新
  async update(c: CardInfo): Promise<void> {
    if (this.store === undefined) {
      return;
    }
    const pred = new relationalStore.RdbPredicates('card');
    pred.equalTo('id', c.id);
    await this.store.update(this.fill(c, false), pred);
  }

  // 按 id 删除
  async remove(id: number): Promise<void> {
    if (this.store === undefined) {
      return;
    }
    const pred = new relationalStore.RdbPredicates('card');
    pred.equalTo('id', id);
    await this.store.delete(pred);
  }

  // 收藏/取消收藏
  async setFavorite(id: number, favorite: number): Promise<void> {
    if (this.store === undefined) {
      return;
    }
    const bucket: relationalStore.ValuesBucket = { 'favorite': favorite };
    const pred = new relationalStore.RdbPredicates('card');
    pred.equalTo('id', id);
    await this.store.update(bucket, pred);
  }

  // 条件查询：关键字（姓名/公司/职位/电话 模糊）+ 分组 + 只看收藏
  async queryAll(keyword: string, group: string, onlyFav: boolean): Promise<CardInfo[]> {
    if (this.store === undefined) {
      return [];
    }
    const pred = new relationalStore.RdbPredicates('card');
    if (onlyFav) {
      pred.equalTo('favorite', 1);
    }
    if (group !== '全部') {
      pred.equalTo('groupName', group);
    }
    if (keyword.trim() !== '') {
      const k: string = '%' + keyword.trim() + '%';
      pred.beginWrap()
        .like('name', k).or().like('company', k)
        .or().like('title', k).or().like('phone', k)
        .endWrap();
    }
    pred.orderByDesc('favorite').orderByDesc('createTime'); // 收藏优先，新的靠前
    const rs = await this.store.query(pred);
    const list: CardInfo[] = [];
    while (rs.goToNextRow()) {
      list.push(this.rowToCard(rs));
    }
    rs.close();
    return list;
  }

  // 按 id 查询
  async getById(id: number): Promise<CardInfo | null> {
    if (this.store === undefined) {
      return null;
    }
    const pred = new relationalStore.RdbPredicates('card');
    pred.equalTo('id', id);
    const rs = await this.store.query(pred);
    let c: CardInfo | null = null;
    if (rs.goToNextRow()) {
      c = this.rowToCard(rs);
    }
    rs.close();
    return c;
  }

  // 总数
  async countAll(): Promise<number> {
    if (this.store === undefined) {
      return 0;
    }
    const pred = new relationalStore.RdbPredicates('card');
    const rs = await this.store.query(pred);
    const n: number = rs.rowCount;
    rs.close();
    return n;
  }
}
