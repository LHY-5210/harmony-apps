import { image } from '@kit.ImageKit';
import { fileIo } from '@kit.CoreFileKit';

export class ImageUtil {
  // 相册 URI → PixelMap；超过 maxSide 按比例缩小，防止超大图撑爆内存
  static async uriToPixelMap(uri: string, maxSide: number): Promise<image.PixelMap> {
    const src: image.ImageSource = image.createImageSource(uri);
    const opts: image.DecodingOptions = {
      desiredPixelFormat: image.PixelMapFormat.RGBA_8888
    };
    const pm: image.PixelMap = await src.createPixelMap(opts);
    const info: image.ImageInfo = await pm.getImageInfo();
    const w: number = info.size.width;
    const h: number = info.size.height;
    const longSide: number = Math.max(w, h);
    if (longSide > maxSide) {
      const s: number = maxSide / longSide;
      await pm.scale(s, s);
    }
    return pm;
  }

  // PixelMap → RGBA8888 字节流（每像素 4 字节），供推理预处理使用
  static async readRgba(pm: image.PixelMap): Promise<ArrayBuffer> {
    const info: image.ImageInfo = await pm.getImageInfo();
    const len: number = info.size.width * info.size.height * 4;
    const buf: ArrayBuffer = new ArrayBuffer(len);
    await pm.readPixelsToBuffer(buf);
    return buf;
  }

  static async widthOf(pm: image.PixelMap): Promise<number> {
    const info: image.ImageInfo = await pm.getImageInfo();
    return info.size.width;
  }

  static async heightOf(pm: image.PixelMap): Promise<number> {
    const info: image.ImageInfo = await pm.getImageInfo();
    return info.size.height;
  }

  // PixelMap → JPEG 文件（列表缩略图用）
  static async saveJpeg(pm: image.PixelMap, path: string, quality: number): Promise<void> {
    const packer: image.ImagePacker = image.createImagePacker();
    const opts: image.PackingOption = { format: 'image/jpeg', quality: quality };
    const data: ArrayBuffer = await packer.packToData(pm, opts);
    const file = fileIo.openSync(path, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
    fileIo.writeSync(file.fd, data);
    fileIo.closeSync(file.fd);
    packer.release();
  }
}
