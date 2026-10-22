import { mindSporeLite } from '@kit.MindSporeLiteKit';

// worker 线程内的 MindSpore Lite 模型缓存（napi 对象不能跨线程，只能在用它的线程内创建）
// 每个线程拿到自己模块实例的 statics，天然隔离
export class MslSessionHolder {
  private static model: mindSporeLite.Model | null = null;
  private static cachedPath: string = '';

  static async get(modelPath: string): Promise<mindSporeLite.Model> {
    if (MslSessionHolder.model === null || MslSessionHolder.cachedPath !== modelPath) {
      const ctx: mindSporeLite.Context = {
        target: ['cpu'],
        cpu: { threadNum: 2, precisionMode: 'enforce_fp32' }
      };
      MslSessionHolder.model = await mindSporeLite.loadModelFromFile(modelPath, ctx);
      MslSessionHolder.cachedPath = modelPath;
    }
    return MslSessionHolder.model;
  }
}
