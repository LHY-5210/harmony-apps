import { common } from '@kit.AbilityKit';
import { fileIo } from '@kit.CoreFileKit';

// 模型文件管理：优先使用云端下载的热更模型（active-版本.ms），否则用内置模型
export class ModelManager {
  private static modelsDir(ctx: common.Context): string {
    return ctx.filesDir + '/models';
  }

  static resolvePath(ctx: common.Context): string {
    const dir: string = ModelManager.modelsDir(ctx);
    try {
      const names: string[] = fileIo.listFileSync(dir);
      const actives: string[] = [];
      for (let i = 0; i < names.length; i++) {
        if (names[i].startsWith('active-') && names[i].endsWith('.ms')) {
          actives.push(names[i]);
        }
      }
      if (actives.length > 0) {
        // 版本号字典序即下载先后，取最后一个
        actives.sort();
        return dir + '/' + actives[actives.length - 1];
      }
    } catch (e) {
      // 目录不存在时回退内置模型
    }
    return dir + '/yolov8n.ms';
  }

  // 本地生效版本：热更文件从文件名解析，内置模型固定 v1.0.0
  static localVersion(ctx: common.Context): string {
    const path: string = ModelManager.resolvePath(ctx);
    const name: string = path.substring(path.lastIndexOf('/') + 1);
    if (name.startsWith('active-') && name.endsWith('.ms')) {
      return name.substring('active-'.length, name.length - '.ms'.length);
    }
    return 'v1.0.0';
  }

  // 下载完成的临时文件改名为带版本号的正式文件
  static apply(ctx: common.Context, version: string, tmpPath: string): string {
    const dst: string = `${ModelManager.modelsDir(ctx)}/active-${version}.ms`;
    try {
      if (fileIo.accessSync(dst)) {
        fileIo.unlinkSync(dst);
      }
    } catch (e) {
      // 目标不存在则直接改名
    }
    fileIo.renameSync(tmpPath, dst);
    return dst;
  }
}
