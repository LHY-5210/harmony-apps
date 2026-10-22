// 留言板数据层：留言模型 + relationalStore 持久化（与名片库风格一致）
// 只负责数据存取，不涉及 UI 与网页桥接
import { relationalStore } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';

export class MessageItem {
  id: number = 0;
  name: string = '';
  content: string = '';
  createTime: number = 0;

  constructor(name: string = '', content: string = '') {
    this.name = name;
    this.content = content;
  }
}

const CREATE_SQL: string =
  `CREATE TABLE IF NOT EXISTS message (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    content TEXT NOT NULL,
    createTime INTEGER
  )`;

export class MessageStore {
  private store: relationalStore.RdbStore | undefined = undefined;

  async init(context: common.UIAbilityContext): Promise<void> {
    if (this.store !== undefined) {
      return;
    }
    const config: relationalStore.StoreConfig = {
      name: 'message.db',
      securityLevel: relationalStore.SecurityLevel.S1
    };
    this.store = await relationalStore.getRdbStore(context, config);
    await this.store.executeSql(CREATE_SQL);
  }

  // 新增留言；返回是否成功
  async add(name: string, content: string): Promise<boolean> {
    if (this.store === undefined || name.trim() === '' || content.trim() === '') {
      return false;
    }
    const bucket: relationalStore.ValuesBucket = {
      'name': name.trim(),
      'content': content.trim(),
      'createTime': Date.now()
    };
    const id = await this.store.insert('message', bucket);
    return id > 0;
  }

  // 查询全部留言（按时间倒序）
  async queryAll(): Promise<MessageItem[]> {
    if (this.store === undefined) {
      return [];
    }
    const pred = new relationalStore.RdbPredicates('message');
    pred.orderByDesc('createTime');
    const rs = await this.store.query(pred);
    const list: MessageItem[] = [];
    while (rs.goToNextRow()) {
      const m = new MessageItem();
      m.id = rs.getLong(rs.getColumnIndex('id'));
      m.name = rs.getString(rs.getColumnIndex('name'));
      m.content = rs.getString(rs.getColumnIndex('content'));
      m.createTime = rs.getLong(rs.getColumnIndex('createTime'));
      list.push(m);
    }
    rs.close();
    return list;
  }
}
