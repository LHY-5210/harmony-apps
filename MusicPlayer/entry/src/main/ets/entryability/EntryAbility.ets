/**
 * EntryAbility.ets —— 应用入口
 * 启动时初始化 RDB 数据中心与播放内核，再加载首页。
 */
import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { SongStore } from '../model/SongStore';
import { PlayerManager } from '../model/PlayerManager';

export default class EntryAbility extends UIAbility {
  async onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): Promise<void> {
    PlayerManager.getInstance().init(this.context);
    await SongStore.getInstance().init(this.context);
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        console.error(`Failed to load content: ${JSON.stringify(err)}`);
      }
    });
  }

  onDestroy(): void {
  }
}
