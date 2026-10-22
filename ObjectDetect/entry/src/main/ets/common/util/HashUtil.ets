import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { fileIo } from '@kit.CoreFileKit';

export class HashUtil {
  // 计算文件 SHA256，用于和云端模型摘要比对
  static async sha256File(path: string): Promise<string> {
    const stat: fileIo.Stat = fileIo.statSync(path);
    const buf: ArrayBuffer = new ArrayBuffer(stat.size);
    const file: fileIo.File = fileIo.openSync(path, fileIo.OpenMode.READ_ONLY);
    fileIo.readSync(file.fd, buf);
    fileIo.closeSync(file.fd);

    const md: cryptoFramework.Md = cryptoFramework.createMd('SHA256');
    await md.update({ data: new Uint8Array(buf) });
    const digest: cryptoFramework.DataBlob = await md.digest();
    const bytes: Uint8Array = digest.data;
    let hex: string = '';
    for (let i = 0; i < bytes.length; i++) {
      const v: number = bytes[i];
      hex += (v < 16 ? '0' : '') + v.toString(16);
    }
    return hex;
  }
}
