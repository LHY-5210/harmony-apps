/**
 * Song.ets —— 歌曲数据模型
 */

/** 音频来源类型：应用内置 rawfile，或应用沙箱中的本地导入文件 */
export class Song {
  /** 业务唯一键：raw 演示歌曲用文件名，导入歌曲用数据库 id */
  key: string;
  title: string;
  artist: string;
  album: string;
  durationMs: number;
  /** rawfile 文件名 或 沙箱绝对路径 */
  src: string;
  /** 封面：rawfile 文件名 或 沙箱绝对路径，空串表示用默认封面 */
  cover: string;
  /** true = 内置 rawfile；false = 沙箱文件 */
  isRaw: boolean;

  constructor(key: string, title: string, artist: string, album: string,
              durationMs: number, src: string, cover: string, isRaw: boolean) {
    this.key = key;
    this.title = title;
    this.artist = artist;
    this.album = album;
    this.durationMs = durationMs;
    this.src = src;
    this.cover = cover;
    this.isRaw = isRaw;
  }
}

/** 自定义歌单 */
export class Playlist {
  id: number;
  name: string;
  songs: Song[];

  constructor(id: number, name: string, songs: Song[]) {
    this.id = id;
    this.name = name;
    this.songs = songs;
  }
}

/** 播放模式 */
export enum PlayMode {
  /** 顺序播放 */
  LIST = 0,
  /** 随机播放 */
  RANDOM = 1,
  /** 单曲循环 */
  SINGLE = 2
}

/** AppStorage 全局键名集中管理，避免散落字符串 */
export class StoreKeys {
  static readonly ALL_SONGS: string = 'allSongs';
  static readonly PLAYLISTS: string = 'playlists';
  static readonly QUEUE: string = 'queue';
  static readonly QUEUE_INDEX: string = 'queueIndex';
  static readonly CUR_SONG: string = 'curSong';
  static readonly IS_PLAYING: string = 'isPlaying';
  static readonly POSITION: string = 'position';
  static readonly DURATION: string = 'duration';
  static readonly VOLUME: string = 'volume';
  static readonly PLAY_MODE: string = 'playMode';
  static readonly LRC_LINES: string = 'lrcLines';
  static readonly VOICE_TIP: string = 'voiceTip';
  static readonly TOAST: string = 'toastMsg';
}
