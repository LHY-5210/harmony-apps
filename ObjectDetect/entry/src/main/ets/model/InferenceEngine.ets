import { taskpool } from '@kit.ArkTS';
import { InferPayload, InferResult } from './Types';
import { infer } from './InferenceWorker';
import { doInfer } from './InferenceCore';

// UI 侧推理门面：防抖锁禁止并发提交（实验要求）
export class InferenceEngine {
  private static instance: InferenceEngine = new InferenceEngine();
  private running: boolean = false;

  static getInstance(): InferenceEngine {
    return InferenceEngine.instance;
  }

  isRunning(): boolean {
    return this.running;
  }

  // 异步推理（TaskPool worker 线程执行）
  async inferAsync(payload: InferPayload): Promise<InferResult> {
    if (this.running) {
      const busy: InferResult = new InferResult();
      busy.error = 'BUSY';
      return busy;
    }
    this.running = true;
    try {
      const task: taskpool.Task = new taskpool.Task(infer, payload);
      const res: Object = await taskpool.execute(task);
      return res as InferResult;
    } catch (e) {
      const fail: InferResult = new InferResult();
      fail.error = JSON.stringify(e);
      return fail;
    } finally {
      this.running = false;
    }
  }

  // 同步推理（主线程执行，用于与 TaskPool 异步对比，会阻塞 UI）
  async inferSync(payload: InferPayload): Promise<InferResult> {
    if (this.running) {
      const busy: InferResult = new InferResult();
      busy.error = 'BUSY';
      return busy;
    }
    this.running = true;
    try {
      return await doInfer(payload);
    } catch (e) {
      const fail: InferResult = new InferResult();
      fail.error = JSON.stringify(e);
      return fail;
    } finally {
      this.running = false;
    }
  }
}
