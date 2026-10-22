/**
 * PlayerManager.ets —— 播放内核
 *
 * 基于 @kit.MediaKit 的 AVPlayer 单例封装：
 * 播放/暂停、上下首、进度拖动 seek、音量、顺序/随机/单曲循环三种模式；
 * 状态通过 AppStorage 与 UI 层实时同步，与界面完全解耦。
 */import { common } from '@kit.AbilityKit';
import { fileIo } from '@kit.CoreFileKit';
import { media } from '@kit.MediaKit';
import { Song, PlayMode, StoreKeys } from './Song';
import { LrcLine } from './LrcParser';
import { SongStore } from './SongStore';

export class PlayerManager {
  private static instance: PlayerManager | null = null;
  private ctx: common.UIAbilityContext | null = null;
  private player: media.AVPlayer | null = null;
  private currentFd: number = -1;
  private hasSrc: boolean = false;
  private listenersBound: boolean = false;
  private pendingSeek: number = -1;

  private constructor() {
  }

  static getInstance(): PlayerManager {
    if (PlayerManager.instance === null) {
      PlayerManager.instance = new PlayerManager();
    }
    return PlayerManager.instance;
  }

  /** 应用启动时初始化全局状态 */
  init(ctx: common.UIAbilityContext): void {
    this.ctx = ctx;
    AppStorage.setOrCreate<Song[]>(StoreKeys.QUEUE, []);
    AppStorage.setOrCreate<number>(StoreKeys.QUEUE_INDEX, -1);
    AppStorage.setOrCreate<Song | null>(StoreKeys.CUR_SONG, null);
    AppStorage.setOrCreate<boolean>(StoreKeys.IS_PLAYING, false);
    AppStorage.setOrCreate<number>(StoreKeys.POSITION, 0);
    AppStorage.setOrCreate<number>(StoreKeys.DURATION, 0);
    AppStorage.setOrCreate<number>(StoreKeys.VOLUME, 1);
    AppStorage.setOrCreate<number>(StoreKeys.PLAY_MODE, PlayMode.LIST);
    AppStorage.setOrCreate<LrcLine[]>(StoreKeys.LRC_LINES, []);
    AppStorage.setOrCreate<string>(StoreKeys.VOICE_TIP, '点击右侧“语音点歌”，说出：播放歌名 / 暂停 / 下一首');
  }

  private async ensurePlayer(): Promise<media.AVPlayer | null> {
    if (this.player !== null) {
      return this.player;
    }
    const av: media.AVPlayer = await media.createAVPlayer();
    this.player = av;
    if (!this.listenersBound) {
      this.listenersBound = true;
      av.on('stateChange', (state: string) => {
        if (state === 'initialized') {
          av.prepare();
        } else if (state === 'prepared') {
          av.setVolume(AppStorage.get<number>(StoreKeys.VOLUME) ?? 1);
          if (this.pendingSeek >= 0) {
            av.seek(this.pendingSeek);
            this.pendingSeek = -1;
          }
          av.play();
        } else if (state === 'playing') {
          AppStorage.setOrCreate<boolean>(StoreKeys.IS_PLAYING, true);
        } else if (state === 'paused') {
          AppStorage.setOrCreate<boolean>(StoreKeys.IS_PLAYING, false);
        } else if (state === 'completed') {
          this.onCompleted();
        }
      });
      av.on('timeUpdate', (timeMs: number) => {
        AppStorage.setOrCreate<number>(StoreKeys.POSITION, timeMs);
      });
      av.on('durationUpdate', (durationMs: number) => {
        if (durationMs > 0) {
          AppStorage.setOrCreate<number>(StoreKeys.DURATION, durationMs);
        }
      });
      av.on('error', (err: Error) => {
        console.error(`[Player] error: ${err?.message}`);
        AppStorage.setOrCreate<boolean>(StoreKeys.IS_PLAYING, false);
      });
    }
    return av;
  }

  // ---------------- 队列与切歌 ----------------

  /** 用给定列表作为播放队列，并从 index 开始播放 */
  async setQueueAndPlay(songs: Song[], index: number): Promise<void> {
    AppStorage.setOrCreate<Song[]>(StoreKeys.QUEUE, songs);
    AppStorage.setOrCreate<number>(StoreKeys.QUEUE_INDEX, index);
    await this.playCurrent();
  }

  async playCurrent(): Promise<void> {
    const songs: Song[] = AppStorage.get<Song[]>(StoreKeys.QUEUE) ?? [];
    const index: number = AppStorage.get<number>(StoreKeys.QUEUE_INDEX) ?? -1;
    if (index < 0 || index >= songs.length) {
      return;
    }
    await this.playSong(songs[index]);
  }

  async playSong(song: Song): Promise<void> {
    if (this.ctx === null) {
      return;
    }
    const av: media.AVPlayer | null = await this.ensurePlayer();
    if (av === null) {
      return;
    }
    AppStorage.setOrCreate<Song>(StoreKeys.CUR_SONG, song);
    AppStorage.setOrCreate<number>(StoreKeys.POSITION, 0);
    AppStorage.setOrCreate<number>(StoreKeys.DURATION, song.durationMs);
    AppStorage.setOrCreate<LrcLine[]>(StoreKeys.LRC_LINES, []);

    // 预加载歌词
    const lines: LrcLine[] = await SongStore.getInstance().loadLrc(song);
    const cur: Song | undefined = AppStorage.get<Song>(StoreKeys.CUR_SONG);
    if (cur !== undefined && cur.key === song.key) {
      AppStorage.setOrCreate<LrcLine[]>(StoreKeys.LRC_LINES, lines);
    }

    // 关闭旧源（仅当已设置过音源时才 reset，避免 idle 状态下的非法调用）
    if (this.hasSrc) {
      await av.reset();
      this.hasSrc = false;
    }
    if (this.currentFd >= 0) {
      try {
        fileIo.closeSync(this.currentFd);
      } catch (e) {
      }
      this.currentFd = -1;
    }

    if (song.isRaw) {
      const raw = this.ctx.resourceManager.getRawFdSync(song.src);
      this.currentFd = raw.fd;
      av.fdSrc = { fd: raw.fd, offset: raw.offset, length: raw.length };
    } else {
      const f: fileIo.File = fileIo.openSync(song.src, fileIo.OpenMode.READ_ONLY);
      this.currentFd = f.fd;
      av.fdSrc = { fd: f.fd };
    }
    this.hasSrc = true;
    // 状态切到 initialized 后由 stateChange 回调自动 prepare → play
  }

  /** 播放/暂停切换 */
  togglePlay(): void {
    const av: media.AVPlayer | null = this.player;
    if (av === null) {
      // 尚未选歌时，默认播放全部歌曲第一首
      const all: Song[] = AppStorage.get<Song[]>(StoreKeys.ALL_SONGS) ?? [];
      if (all.length > 0) {
        this.setQueueAndPlay(all, 0);
      }
      return;
    }
    if (av.state === 'playing') {
      av.pause();
    } else if (av.state === 'paused' || av.state === 'completed') {
      av.play();
    } else {
      this.playCurrent();
    }
  }

  /** 显式暂停（语音指令用） */
  pausePlay(): void {
    if (this.player !== null && this.player.state === 'playing') {
      this.player.pause();
    }
  }

  /** 显式恢复（语音指令用） */
  resumePlay(): void {
    const av: media.AVPlayer | null = this.player;
    if (av === null) {
      const all: Song[] = AppStorage.get<Song[]>(StoreKeys.ALL_SONGS) ?? [];
      if (all.length > 0) {
        this.setQueueAndPlay(all, 0);
      }
      return;
    }
    if (av.state === 'paused' || av.state === 'completed') {
      av.play();
    } else if (av.state === 'idle') {
      this.playCurrent();
    }
  }

  /** 拖动进度条 */
  seekTo(ms: number): void {
    const av: media.AVPlayer | null = this.player;
    if (av === null) {
      return;
    }
    AppStorage.setOrCreate<number>(StoreKeys.POSITION, ms);
    if (av.state === 'prepared' || av.state === 'initialized') {
      this.pendingSeek = ms;
    } else {
      av.seek(ms);
    }
  }

  setVolume(v: number): void {
    AppStorage.setOrCreate<number>(StoreKeys.VOLUME, v);
    if (this.player !== null) {
      this.player.setVolume(v);
    }
  }

  /** 顺序 → 随机 → 单曲循环 */
  cycleMode(): void {
    const m: number = AppStorage.get<number>(StoreKeys.PLAY_MODE) ?? PlayMode.LIST;
    const next: number = (m + 1) % 3;
    AppStorage.setOrCreate<number>(StoreKeys.PLAY_MODE, next);
    // 单曲循环模式直接交给 AVPlayer 的 loop 属性
    if (this.player !== null) {
      this.player.loop = next === PlayMode.SINGLE;
    }
  }

  /** 手动下一首（任何模式下都切到下一首） */
  next(): void {
    const songs: Song[] = AppStorage.get<Song[]>(StoreKeys.QUEUE) ?? [];
    if (songs.length === 0) {
      return;
    }
    const mode: number = AppStorage.get<number>(StoreKeys.PLAY_MODE) ?? PlayMode.LIST;
    let index: number = AppStorage.get<number>(StoreKeys.QUEUE_INDEX) ?? -1;
    if (mode === PlayMode.RANDOM && songs.length > 1) {
      let r: number = index;
      while (r === index) {
        r = Math.floor(Math.random() * songs.length);
      }
      index = r;
    } else {
      index = (index + 1) % songs.length;
    }
    AppStorage.setOrCreate<number>(StoreKeys.QUEUE_INDEX, index);
    this.playCurrent();
  }

  prev(): void {
    const songs: Song[] = AppStorage.get<Song[]>(StoreKeys.QUEUE) ?? [];
    if (songs.length === 0) {
      return;
    }
    let index: number = AppStorage.get<number>(StoreKeys.QUEUE_INDEX) ?? -1;
    // 播放超过 3 秒按上一首，行为为重新播放当前歌曲
    const pos: number = AppStorage.get<number>(StoreKeys.POSITION) ?? 0;
    if (pos > 3000) {
      this.seekTo(0);
      return;
    }
    index = index - 1 < 0 ? songs.length - 1 : index - 1;
    AppStorage.setOrCreate<number>(StoreKeys.QUEUE_INDEX, index);
    this.playCurrent();
  }

  /** 点击播放列表中的某一首：跳到该位置播放 */
  jumpTo(index: number): void {
    const songs: Song[] = AppStorage.get<Song[]>(StoreKeys.QUEUE) ?? [];
    if (index < 0 || index >= songs.length) {
      return;
    }
    AppStorage.setOrCreate<number>(StoreKeys.QUEUE_INDEX, index);
    this.playCurrent();
  }

  /** 从队列中删除一首（播放列表页用） */
  removeFromQueue(index: number): void {
    const songs: Song[] = AppStorage.get<Song[]>(StoreKeys.QUEUE) ?? [];
    if (index < 0 || index >= songs.length) {
      return;
    }
    const curIndex: number = AppStorage.get<number>(StoreKeys.QUEUE_INDEX) ?? -1;
    const removed: Song[] = songs.splice(index, 1);
    AppStorage.setOrCreate<Song[]>(StoreKeys.QUEUE, songs);
    if (index === curIndex) {
      if (songs.length === 0) {
        AppStorage.setOrCreate<number>(StoreKeys.QUEUE_INDEX, -1);
        if (this.player !== null) {
          this.player.reset();
        }
        AppStorage.setOrCreate<Song | null>(StoreKeys.CUR_SONG, null);
        AppStorage.setOrCreate<boolean>(StoreKeys.IS_PLAYING, false);
      } else {
        const ni: number = index >= songs.length ? songs.length - 1 : index;
        AppStorage.setOrCreate<number>(StoreKeys.QUEUE_INDEX, ni);
        this.playCurrent();
      }
    } else if (index < curIndex) {
      AppStorage.setOrCreate<number>(StoreKeys.QUEUE_INDEX, curIndex - 1);
    }
  }

  clearQueue(): void {
    AppStorage.setOrCreate<Song[]>(StoreKeys.QUEUE, []);
    AppStorage.setOrCreate<number>(StoreKeys.QUEUE_INDEX, -1);
    AppStorage.setOrCreate<Song | null>(StoreKeys.CUR_SONG, null);
    AppStorage.setOrCreate<boolean>(StoreKeys.IS_PLAYING, false);
    if (this.player !== null) {
      this.player.reset();
    }
  }

  // ---------------- 自动连播 ----------------

  private onCompleted(): void {
    const mode: number = AppStorage.get<number>(StoreKeys.PLAY_MODE) ?? PlayMode.LIST;
    if (mode === PlayMode.SINGLE) {
      // loop=true 时 AVPlayer 一般会自动重播，这里兜底
      this.seekTo(0);
      if (this.player !== null) {
        this.player.play();
      }
      return;
    }
    this.next();
  }
}
