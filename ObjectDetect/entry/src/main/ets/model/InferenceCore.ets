import { mindSporeLite } from '@kit.MindSporeLiteKit';
import { InferPayload, InferResult, InferTimings, LetterboxMeta } from './Types';
import { Preprocess } from './Preprocess';
import { Postprocess } from './Postprocess';
import { MslSessionHolder } from './MslSessionHolder';

// 推理核心：TaskPool 与主线程同步调用共用同一实现
export async function doInfer(payload: InferPayload): Promise<InferResult> {
  const result: InferResult = new InferResult();
  try {
    const model: mindSporeLite.Model = await MslSessionHolder.get(payload.modelPath);

    // ---- 预处理：letterbox + NCHW/NHWC ----
    const inputs: mindSporeLite.MSTensor[] = model.getInputs();
    const inputTensor: mindSporeLite.MSTensor = inputs[0];
    result.inputName = inputTensor.name;
    const useNhwc: boolean = inputTensor.format === mindSporeLite.Format.NHWC;
    const t0: number = Date.now();
    const meta: LetterboxMeta = Preprocess.makeMeta(payload.imgW, payload.imgH, payload.inputSize);
    const inputData: Float32Array = useNhwc
      ? Preprocess.toNhwc(payload.rgba, payload.imgW, payload.imgH, payload.inputSize)
      : Preprocess.toNchw(payload.rgba, payload.imgW, payload.imgH, payload.inputSize);
    const t1: number = Date.now();

    // ---- 推理 ----
    inputTensor.setData(inputData.buffer as ArrayBuffer);
    const outputs: mindSporeLite.MSTensor[] = await model.predict(inputs);
    const t2: number = Date.now();

    // ---- 后处理：解析 + NMS + 坐标还原 ----
    const outTensor: mindSporeLite.MSTensor = outputs[0];
    const outShape: number[] = outTensor.shape;
    const outData: Float32Array = new Float32Array(outTensor.getData());
    result.outputShape = outShape.join('x');

    if (outShape.length === 3 && outShape[2] === 6) {
      result.boxes = Postprocess.parseEnd2End(outData, outShape, meta,
        payload.imgW, payload.imgH, payload.confThreshold);
    } else {
      result.boxes = Postprocess.parseYolo(outData, outShape, meta,
        payload.imgW, payload.imgH, payload.confThreshold);
    }
    const t3: number = Date.now();

    const timings: InferTimings = new InferTimings();
    timings.preMs = t1 - t0;
    timings.inferMs = t2 - t1;
    timings.postMs = t3 - t2;
    result.timings = timings;
  } catch (e) {
    result.error = JSON.stringify(e);
  }
  return result;
}
