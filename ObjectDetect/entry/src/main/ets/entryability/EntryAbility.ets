import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { fileIo } from '@kit.CoreFileKit';

const TAG = 'ObjectDetect';

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(0x0000, TAG, 'onCreate');
    this.copyModelIfNeeded();
  }

  // 首启把 rawfile 里的模型拷到 filesDir/models/，MindSpore Lite 从沙箱路径加载
  private copyModelIfNeeded(): void {
    try {
      const dir: string = this.context.filesDir + '/models';
      const dst: string = dir + '/yolov8n.ms';
      let exists: boolean = false;
      try {
        exists = fileIo.accessSync(dst);
      } catch (e) {
        exists = false;
      }
      if (exists) {
        hilog.info(0x0000, TAG, 'model already in sandbox');
        return;
      }
      const bytes: Uint8Array = this.context.resourceManager.getRawFileContentSync('yolov8n.ms');
      fileIo.mkdir(dir, true);
      const fd: number = fileIo.openSync(dst, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC).fd;
      fileIo.writeSync(fd, bytes.buffer);
      fileIo.closeSync(fd);
      hilog.info(0x0000, TAG, 'model copied: %{public}d bytes', bytes.byteLength);
    } catch (e) {
      hilog.error(0x0000, TAG, 'copyModel failed %{public}s', JSON.stringify(e));
    }
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(0x0000, TAG, 'onWindowStageCreate');
    windowStage.loadContent('pages/Index', (err: BusinessError) => {
      if (err.code) {
        hilog.error(0x0000, TAG, `loadContent failed: ${err.code}`);
        return;
      }
      hilog.info(0x0000, TAG, 'loadContent success');
    });
  }

  onDestroy(): void {
    hilog.info(0x0000, TAG, 'onDestroy');
  }
}
