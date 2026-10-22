import { InferPayload, InferResult } from './Types';
import { doInfer } from './InferenceCore';

// TaskPool 入口：@Concurrent 只能引用 import 符号或局部变量，故核心逻辑放在 InferenceCore
@Concurrent
export async function infer(payload: InferPayload): Promise<InferResult> {
  const result: InferResult = await doInfer(payload);
  return result;
}
