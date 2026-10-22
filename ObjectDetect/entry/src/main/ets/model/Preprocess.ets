import { LetterboxMeta } from './Types';

// RGBA Uint8 → letterbox 缩放（双线性、灰边 114）→ /255 归一化 → NCHW Float32
export class Preprocess {
  static toNchw(rgba: ArrayBuffer, imgW: number, imgH: number, inputSize: number): Float32Array {
    const out: Float32Array = new Float32Array(3 * inputSize * inputSize);
    const src: Uint8Array = new Uint8Array(rgba);
    const scale: number = Math.min(inputSize / imgW, inputSize / imgH);
    const newW: number = Math.round(imgW * scale);
    const newH: number = Math.round(imgH * scale);
    const padX: number = Math.floor((inputSize - newW) / 2);
    const padY: number = Math.floor((inputSize - newH) / 2);

    // 先填 114/255 灰底
    const gray: number = 114.0 / 255.0;
    out.fill(gray);

    const planeSize: number = inputSize * inputSize;
    for (let dy = 0; dy < newH; dy++) {
      const fy: number = (dy + 0.5) / scale - 0.5;
      let y0: number = Math.floor(fy);
      let y1: number = y0 + 1;
      const wy: number = fy - y0;
      if (y0 < 0) { y0 = 0; }
      if (y1 > imgH - 1) { y1 = imgH - 1; }
      const oy: number = padY + dy;
      for (let dx = 0; dx < newW; dx++) {
        const fx: number = (dx + 0.5) / scale - 0.5;
        let x0: number = Math.floor(fx);
        let x1: number = x0 + 1;
        const wx: number = fx - x0;
        if (x0 < 0) { x0 = 0; }
        if (x1 > imgW - 1) { x1 = imgW - 1; }
        const ox: number = padX + dx;

        const i00: number = (y0 * imgW + x0) * 4;
        const i01: number = (y0 * imgW + x1) * 4;
        const i10: number = (y1 * imgW + x0) * 4;
        const i11: number = (y1 * imgW + x1) * 4;

        for (let c = 0; c < 3; c++) {
          const v00: number = src[i00 + c];
          const v01: number = src[i01 + c];
          const v10: number = src[i10 + c];
          const v11: number = src[i11 + c];
          const top: number = v00 + (v01 - v00) * wx;
          const bot: number = v10 + (v11 - v10) * wx;
          const v: number = (top + (bot - top) * wy) / 255.0;
          out[c * planeSize + oy * inputSize + ox] = v;
        }
      }
    }
    return out;
  }

  // MSL 会把输入图转成 NHWC，此时按 HWC 交织写入
  static toNhwc(rgba: ArrayBuffer, imgW: number, imgH: number, inputSize: number): Float32Array {
    const out: Float32Array = new Float32Array(inputSize * inputSize * 3);
    const src: Uint8Array = new Uint8Array(rgba);
    const scale: number = Math.min(inputSize / imgW, inputSize / imgH);
    const newW: number = Math.round(imgW * scale);
    const newH: number = Math.round(imgH * scale);
    const padX: number = Math.floor((inputSize - newW) / 2);
    const padY: number = Math.floor((inputSize - newH) / 2);

    out.fill(114.0 / 255.0);

    for (let dy = 0; dy < newH; dy++) {
      const fy: number = (dy + 0.5) / scale - 0.5;
      let y0: number = Math.floor(fy);
      let y1: number = y0 + 1;
      const wy: number = fy - y0;
      if (y0 < 0) { y0 = 0; }
      if (y1 > imgH - 1) { y1 = imgH - 1; }
      const oy: number = padY + dy;
      for (let dx = 0; dx < newW; dx++) {
        const fx: number = (dx + 0.5) / scale - 0.5;
        let x0: number = Math.floor(fx);
        let x1: number = x0 + 1;
        const wx: number = fx - x0;
        if (x0 < 0) { x0 = 0; }
        if (x1 > imgW - 1) { x1 = imgW - 1; }
        const ox: number = padX + dx;

        const i00: number = (y0 * imgW + x0) * 4;
        const i01: number = (y0 * imgW + x1) * 4;
        const i10: number = (y1 * imgW + x0) * 4;
        const i11: number = (y1 * imgW + x1) * 4;
        const base: number = (oy * inputSize + ox) * 3;

        for (let c = 0; c < 3; c++) {
          const v00: number = src[i00 + c];
          const v01: number = src[i01 + c];
          const v10: number = src[i10 + c];
          const v11: number = src[i11 + c];
          const top: number = v00 + (v01 - v00) * wx;
          const bot: number = v10 + (v11 - v10) * wx;
          out[base + c] = (top + (bot - top) * wy) / 255.0;
        }
      }
    }
    return out;
  }

  static makeMeta(imgW: number, imgH: number, inputSize: number): LetterboxMeta {
    const meta: LetterboxMeta = new LetterboxMeta();
    meta.scale = Math.min(inputSize / imgW, inputSize / imgH);
    const newW: number = Math.round(imgW * meta.scale);
    const newH: number = Math.round(imgH * meta.scale);
    meta.padX = Math.floor((inputSize - newW) / 2);
    meta.padY = Math.floor((inputSize - newH) / 2);
    meta.inputSize = inputSize;
    return meta;
  }
}
