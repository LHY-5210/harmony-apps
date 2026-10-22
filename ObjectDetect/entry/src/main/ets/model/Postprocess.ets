import { DetectionBox, LetterboxMeta } from './Types';

const COCO_NAMES: string[] = [
  'person', 'bicycle', 'car', 'motorcycle', 'airplane', 'bus', 'train', 'truck', 'boat',
  'traffic light', 'fire hydrant', 'stop sign', 'parking meter', 'bench', 'bird', 'cat',
  'dog', 'horse', 'sheep', 'cow', 'elephant', 'bear', 'zebra', 'giraffe', 'backpack',
  'umbrella', 'handbag', 'tie', 'suitcase', 'frisbee', 'skis', 'snowboard', 'sports ball',
  'kite', 'baseball bat', 'baseball glove', 'skateboard', 'surfboard', 'tennis racket',
  'bottle', 'wine glass', 'cup', 'fork', 'knife', 'spoon', 'bowl', 'banana', 'apple',
  'sandwich', 'orange', 'broccoli', 'carrot', 'hot dog', 'pizza', 'donut', 'cake', 'chair',
  'couch', 'potted plant', 'bed', 'dining table', 'toilet', 'tv', 'laptop', 'mouse',
  'remote', 'keyboard', 'cell phone', 'microwave', 'oven', 'toaster', 'sink',
  'refrigerator', 'book', 'clock', 'vase', 'scissors', 'teddy bear', 'hair drier', 'toothbrush'
];

// 常见类别中文名（清单展示用，未列出的回退英文）
const ZH_NAMES: Record<string, string> = {
  'person': '人', 'bicycle': '自行车', 'car': '汽车', 'motorcycle': '摩托车', 'bus': '公交车',
  'truck': '卡车', 'chair': '椅子', 'couch': '沙发', 'bed': '床', 'dining table': '餐桌',
  'bottle': '瓶子', 'cup': '水杯', 'bowl': '碗', 'fork': '叉子', 'knife': '刀', 'spoon': '勺子',
  'cell phone': '手机', 'keyboard': '键盘', 'mouse': '鼠标', 'laptop': '笔记本电脑',
  'tv': '电视', 'remote': '遥控器', 'book': '书本', 'clock': '时钟', 'backpack': '背包',
  'handbag': '手提包', 'suitcase': '行李箱', 'umbrella': '雨伞', 'cat': '猫', 'dog': '狗',
  'bird': '鸟', 'apple': '苹果', 'banana': '香蕉', 'orange': '橙子', 'pizza': '披萨',
  'toilet': '马桶', 'sink': '水槽', 'refrigerator': '冰箱', 'microwave': '微波炉',
  'oven': '烤箱', 'vase': '花瓶', 'scissors': '剪刀', 'teddy bear': '泰迪熊',
  'potted plant': '盆栽', 'sports ball': '球', 'skateboard': '滑板'
};

export class Postprocess {
  static labelOf(classId: number): string {
    if (classId < 0 || classId >= COCO_NAMES.length) {
      return `cls${classId}`;
    }
    const en: string = COCO_NAMES[classId];
    const zh: string | undefined = ZH_NAMES[en];
    return zh !== undefined ? zh : en;
  }

  static englishOf(classId: number): string {
    if (classId < 0 || classId >= COCO_NAMES.length) {
      return `cls${classId}`;
    }
    return COCO_NAMES[classId];
  }

  static classCount(): number {
    return COCO_NAMES.length;
  }

  // 解析 YOLOv8/v13 系输出 [1, 4+numClasses, anchors]（通道主序），过滤 + 逆映射
  static parseYolo(out: Float32Array, shape: number[], meta: LetterboxMeta,
    imgW: number, imgH: number, confThr: number): DetectionBox[] {
    const dims: number = shape.length >= 3 ? shape[1] : 84;
    const anchors: number = shape.length >= 3 ? shape[2] : 8400;
    const numClasses: number = dims - 4;
    const result: DetectionBox[] = [];
    for (let i = 0; i < anchors; i++) {
      let bestScore: number = 0;
      let bestCls: number = -1;
      for (let c = 0; c < numClasses; c++) {
        const s: number = out[(4 + c) * anchors + i];
        if (s > bestScore) {
          bestScore = s;
          bestCls = c;
        }
      }
      if (bestScore < confThr || bestCls < 0) {
        continue;
      }
      const cx: number = out[0 * anchors + i];
      const cy: number = out[1 * anchors + i];
      const w: number = out[2 * anchors + i];
      const h: number = out[3 * anchors + i];
      // 模型输入坐标 → 原图坐标（去 padding 再除缩放）
      let x1: number = (cx - w / 2 - meta.padX) / meta.scale;
      let y1: number = (cy - h / 2 - meta.padY) / meta.scale;
      let x2: number = (cx + w / 2 - meta.padX) / meta.scale;
      let y2: number = (cy + h / 2 - meta.padY) / meta.scale;
      x1 = Math.max(0, Math.min(imgW - 1, x1));
      y1 = Math.max(0, Math.min(imgH - 1, y1));
      x2 = Math.max(0, Math.min(imgW - 1, x2));
      y2 = Math.max(0, Math.min(imgH - 1, y2));
      const box: DetectionBox = new DetectionBox();
      box.x1 = x1; box.y1 = y1; box.x2 = x2; box.y2 = y2;
      box.score = bestScore;
      box.classId = bestCls;
      box.label = Postprocess.labelOf(bestCls);
      result.push(box);
    }
    return Postprocess.nms(result, 0.45);
  }

  // end2end 输出兜底 [1, N, 6]：x1,y1,x2,y2,score,cls（模型坐标）
  static parseEnd2End(out: Float32Array, shape: number[], meta: LetterboxMeta,
    imgW: number, imgH: number, confThr: number): DetectionBox[] {
    const n: number = shape.length >= 2 ? shape[1] : 0;
    const result: DetectionBox[] = [];
    for (let i = 0; i < n; i++) {
      const base: number = i * 6;
      const score: number = out[base + 4];
      if (score < confThr) {
        continue;
      }
      const cls: number = Math.round(out[base + 5]);
      let x1: number = (out[base + 0] - meta.padX) / meta.scale;
      let y1: number = (out[base + 1] - meta.padY) / meta.scale;
      let x2: number = (out[base + 2] - meta.padX) / meta.scale;
      let y2: number = (out[base + 3] - meta.padY) / meta.scale;
      x1 = Math.max(0, Math.min(imgW - 1, x1));
      y1 = Math.max(0, Math.min(imgH - 1, y1));
      x2 = Math.max(0, Math.min(imgW - 1, x2));
      y2 = Math.max(0, Math.min(imgH - 1, y2));
      const box: DetectionBox = new DetectionBox();
      box.x1 = x1; box.y1 = y1; box.x2 = x2; box.y2 = y2;
      box.score = score;
      box.classId = cls;
      box.label = Postprocess.labelOf(cls);
      result.push(box);
    }
    return result;
  }

  // 类别无关 NMS
  static nms(boxes: DetectionBox[], iouThr: number): DetectionBox[] {
    const sorted: DetectionBox[] = boxes.slice().sort((a: DetectionBox, b: DetectionBox) => b.score - a.score);
    const keep: DetectionBox[] = [];
    const suppressed: boolean[] = new Array<boolean>(sorted.length).fill(false);
    for (let i = 0; i < sorted.length; i++) {
      if (suppressed[i]) {
        continue;
      }
      keep.push(sorted[i]);
      for (let j = i + 1; j < sorted.length; j++) {
        if (suppressed[j]) {
          continue;
        }
        if (Postprocess.iou(sorted[i], sorted[j]) > iouThr) {
          suppressed[j] = true;
        }
      }
    }
    return keep;
  }

  static iou(a: DetectionBox, b: DetectionBox): number {
    const ix1: number = Math.max(a.x1, b.x1);
    const iy1: number = Math.max(a.y1, b.y1);
    const ix2: number = Math.min(a.x2, b.x2);
    const iy2: number = Math.min(a.y2, b.y2);
    const iw: number = Math.max(0, ix2 - ix1);
    const ih: number = Math.max(0, iy2 - iy1);
    const inter: number = iw * ih;
    const areaA: number = (a.x2 - a.x1) * (a.y2 - a.y1);
    const areaB: number = (b.x2 - b.x1) * (b.y2 - b.y1);
    const union: number = areaA + areaB - inter;
    return union > 0 ? inter / union : 0;
  }
}
