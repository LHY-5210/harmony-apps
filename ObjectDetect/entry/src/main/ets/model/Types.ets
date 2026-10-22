// 跨线程序列化数据载体：全部保持纯数据字段（TaskPool 传递时方法会丢失）

export class DetectionBox {
  x1: number = 0;
  y1: number = 0;
  x2: number = 0;
  y2: number = 0;
  score: number = 0;
  classId: number = 0;
  label: string = '';
}

export class InferTimings {
  preMs: number = 0;
  inferMs: number = 0;
  postMs: number = 0;
}

export class InferResult {
  boxes: DetectionBox[] = [];
  timings: InferTimings = new InferTimings();
  error: string = '';
  inputName: string = '';
  outputShape: string = '';
}

export class InferPayload {
  rgba: ArrayBuffer = new ArrayBuffer(0);
  imgW: number = 0;
  imgH: number = 0;
  modelPath: string = '';
  confThreshold: number = 0.25;
  inputSize: number = 640;
}

export class LetterboxMeta {
  scale: number = 1;
  padX: number = 0;
  padY: number = 0;
  inputSize: number = 640;
}
