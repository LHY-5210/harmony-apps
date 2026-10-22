/**
 * SongStore.ets —— 音乐数据中心
 *
 * 职责：
 * 1. 提供内置演示歌曲（rawfile，无设备音频时也能完成实验演示）
 * 2. 通过系统音频选择器导入本地音频，AVMetadataExtractor 读取 ID3 元数据
 *    （歌名 / 歌手 / 专辑 / 时长），并复制到应用沙箱持久化
 * 3. relationalStore(RDB) 存储：导入歌曲、自定义歌单、歌单-歌曲关系
 */
import { common } from '@kit.AbilityKit';
import { fileIo, picker } from '@kit.CoreFileKit';
import { media } from '@kit.MediaKit';
import { relationalStore } from '@kit.ArkData';
import { util } from '@kit.ArkTS';
import { Song, Playlist, StoreKeys } from './Song';
import { LrcLine, parseLrc } from './LrcParser';

const DB_NAME: string = 'music.db';
const TABLE_SONG: string = 'song';
const TABLE_LIST: string = 'playlist';
const TABLE_REL: string = 'playlist_song';

/** 内置演示歌曲（时长与 rawfile 中生成的 WAV 保持一致：24 秒） */
const DEMO_DURATION: number = 24000;

export class SongStore {
  private static instance: SongStore | null = null;
  private ctx: common.UIAbilityContext | null = null;
  private db: relationalStore.RdbStore | null = null;
  private importDir: string = '';

  private constructor() {
  }

  static getInstance(): SongStore {
    if (SongStore.instance === null) {
      SongStore.instance = new SongStore();
    }
    return SongStore.instance;
  }

  /** 应用启动时调用：建库建表、加载数据到 AppStorage */
  async init(ctx: common.UIAbilityContext): Promise<void> {
    this.ctx = ctx;
    this.importDir = ctx.filesDir + '/imports';
    try {
      fileIo.mkdirSync(this.importDir, true);
    } catch (e) {
      // 目录已存在时忽略
    }
    const config: relationalStore.StoreConfig = {
      name: DB_NAME,
      securityLevel: relationalStore.SecurityLevel.S1
    };
    this.db = await relationalStore.getRdbStore(ctx, config);
    await this.db.executeSql(
      `CREATE TABLE IF NOT EXISTS ${TABLE_SONG} (` +
      'id INTEGER PRIMARY KEY AUTOINCREMENT, ' +
      'title TEXT NOT NULL, ' +
      'artist TEXT, ' +
      'album TEXT, ' +
      'duration INTEGER DEFAULT 0, ' +
      'path TEXT NOT NULL UNIQUE, ' +
      'cover TEXT)'
    );
    await this.db.executeSql(
      `CREATE TABLE IF NOT EXISTS ${TABLE_LIST} (` +
      'id INTEGER PRIMARY KEY AUTOINCREMENT, ' +
      'name TEXT NOT NULL, ' +
      'created_at INTEGER)'
    );
    await this.db.executeSql(
      `CREATE TABLE IF NOT EXISTS ${TABLE_REL} (` +
      'id INTEGER PRIMARY KEY AUTOINCREMENT, ' +
      'playlist_id INTEGER NOT NULL, ' +
      'song_id INTEGER NOT NULL, ' +
      'UNIQUE(playlist_id, song_id))'
    );
    await this.refreshAllSongs();
    await this.refreshPlaylists();
  }

  // ---------------- 内置演示歌曲 ----------------

  private demoSongs(): Song[] {
    return [
      new Song('raw:demo1.wav', '晨光序曲', '演示乐队', '《悦动音乐》实验碟', DEMO_DURATION,
        'demo1.wav', 'cover1.jpg', true),
      new Song('raw:demo2.wav', '河畔清风', '演示乐队', '《悦动音乐》实验碟', DEMO_DURATION,
        'demo2.wav', 'cover2.jpg', true),
      new Song('raw:demo3.wav', '星夜漫步', '演示乐队', '《悦动音乐》实验碟', DEMO_DURATION,
        'demo3.wav', 'cover3.jpg', true)
    ];
  }

  // ---------------- 本地音乐导入（扫描） ----------------

  /**
   * 调起系统音频选择器（对媒体库进行选择式扫描，无需敏感权限），
   * 自动读取 ID3 元数据并复制进沙箱，返回新导入数量。
   */
  async importLocalAudio(): Promise<number> {
    if (this.ctx === null) {
      return 0;
    }
    const audioPicker: picker.AudioViewPicker = new picker.AudioViewPicker();
    const options: picker.AudioSelectOptions = {
      maxSelectNumber: 50
    };
    const uris: string[] = await audioPicker.select(options);
    if (uris === undefined || uris.length === 0) {
      return 0;
    }
    let count: number = 0;
    for (let i = 0; i < uris.length; i++) {
      const ok: boolean = await this.importOne(uris[i]);
      if (ok) {
        count++;
      }
    }
    if (count > 0) {
      await this.refreshAllSongs();
      await this.refreshPlaylists();
    }
    return count;
  }

  private async importOne(uri: string): Promise<boolean> {
    if (this.db === null) {
      return false;
    }
    let fd: number = -1;
    try {
      const file: fileIo.File = fileIo.openSync(uri, fileIo.OpenMode.READ_ONLY);
      fd = file.fd;

      // 读取 ID3 / 容器元数据
      let title: string = '未知歌曲';
      let artist: string = '未知歌手';
      let album: string = '未知专辑';
      let durationMs: number = 0;
      let ext: string = '.mp3';
      try {
        const extractor: media.AVMetadataExtractor = await media.createAVMetadataExtractor();
        extractor.fdSrc = { fd: fd };
        const meta: media.AVMetadata = await extractor.fetchMetadata();
        if (meta.title !== undefined && meta.title.length > 0) {
          title = meta.title;
        }
        if (meta.artist !== undefined && meta.artist.length > 0) {
          artist = meta.artist;
        }
        if (meta.album !== undefined && meta.album.length > 0) {
          album = meta.album;
        }
        if (meta.duration !== undefined && meta.duration.length > 0) {
          durationMs = parseInt(meta.duration, 10);
        }
        if (meta.mimeType !== undefined) {
          ext = this.extFromMime(meta.mimeType);
        }
      } catch (e1) {
        // 个别文件元数据读取失败时，使用默认信息继续导入
      }

      // 复制进应用沙箱，保证 RDB 路径长期有效
      const uuid: string = util.generateRandomUUID(false);
      const destPath: string = `${this.importDir}/${uuid}${ext}`;
      fileIo.copyFileSync(fd, destPath);

      const bucket: relationalStore.ValuesBucket = {
        title: title,
        artist: artist,
        album: album,
        duration: durationMs,
        path: destPath,
        cover: ''
      };
      await this.db.insert(TABLE_SONG, bucket, relationalStore.ConflictResolution.ON_CONFLICT_IGNORE);
      return true;
    } catch (e2) {
      return false;
    } finally {
      if (fd >= 0) {
        try {
          fileIo.closeSync(fd);
        } catch (e3) {
        }
      }
    }
  }

  private extFromMime(mime: string): string {
    if (mime.includes('wav') || mime.includes('wave')) {
      return '.wav';
    }
    if (mime.includes('flac')) {
      return '.flac';
    }
    if (mime.includes('ogg')) {
      return '.ogg';
    }
    if (mime.includes('aac') || mime.includes('mp4')) {
      return '.aac';
    }
    if (mime.includes('m4a')) {
      return '.m4a';
    }
    return '.mp3';
  }

  // ---------------- 查询与刷新 ----------------

  private async queryImportedSongs(): Promise<Song[]> {
    const out: Song[] = [];
    if (this.db === null) {
      return out;
    }
    const rs: relationalStore.ResultSet = await this.db.querySql(
      `SELECT id, title, artist, album, duration, path, cover FROM ${TABLE_SONG} ORDER BY id DESC`);
    while (rs.goToNextRow()) {
      const id: number = rs.getLong(rs.getColumnIndex('id'));
      const title: string = rs.getString(rs.getColumnIndex('title'));
      const artist: string = rs.getString(rs.getColumnIndex('artist'));
      const album: string = rs.getString(rs.getColumnIndex('album'));
      const duration: number = rs.getLong(rs.getColumnIndex('duration'));
      const path: string = rs.getString(rs.getColumnIndex('path'));
      const cover: string = rs.getString(rs.getColumnIndex('cover'));
      out.push(new Song(`db:${id}`, title, artist, album, duration, path, cover, false));
    }
    rs.close();
    return out;
  }

  /** 全部歌曲 = 内置演示 + 本地导入，刷新到 AppStorage */
  async refreshAllSongs(): Promise<void> {
    const imported: Song[] = await this.queryImportedSongs();
    const all: Song[] = this.demoSongs().concat(imported);
    AppStorage.setOrCreate<Song[]>(StoreKeys.ALL_SONGS, all);
  }

  async refreshPlaylists(): Promise<void> {
    const lists: Playlist[] = [];
    if (this.db === null) {
      AppStorage.setOrCreate<Playlist[]>(StoreKeys.PLAYLISTS, lists);
      return;
    }
    const rs: relationalStore.ResultSet = await this.db.querySql(
      `SELECT id, name FROM ${TABLE_LIST} ORDER BY id ASC`);
    while (rs.goToNextRow()) {
      const id: number = rs.getLong(rs.getColumnIndex('id'));
      const name: string = rs.getString(rs.getColumnIndex('name'));
      const songs: Song[] = await this.querySongsOfPlaylist(id);
      lists.push(new Playlist(id, name, songs));
    }
    rs.close();
    AppStorage.setOrCreate<Playlist[]>(StoreKeys.PLAYLISTS, lists);
  }

  private async querySongsOfPlaylist(pid: number): Promise<Song[]> {
    const out: Song[] = [];
    if (this.db === null) {
      return out;
    }
    const rs: relationalStore.ResultSet = await this.db.querySql(
      `SELECT s.id, s.title, s.artist, s.album, s.duration, s.path, s.cover ` +
      `FROM ${TABLE_REL} r INNER JOIN ${TABLE_SONG} s ON r.song_id = s.id ` +
      `WHERE r.playlist_id = ${pid} ORDER BY r.id ASC`);
    while (rs.goToNextRow()) {
      const id: number = rs.getLong(rs.getColumnIndex('id'));
      out.push(new Song(
        `db:${id}`,
        rs.getString(rs.getColumnIndex('title')),
        rs.getString(rs.getColumnIndex('artist')),
        rs.getString(rs.getColumnIndex('album')),
        rs.getLong(rs.getColumnIndex('duration')),
        rs.getString(rs.getColumnIndex('path')),
        rs.getString(rs.getColumnIndex('cover')),
        false));
    }
    rs.close();
    return out;
  }

  // ---------------- 歌单增删改 ----------------

  async createPlaylist(name: string): Promise<void> {
    if (this.db === null || name.trim().length === 0) {
      return;
    }
    await this.db.insert(TABLE_LIST, {
      name: name.trim(),
      created_at: Date.now()
    });
    await this.refreshPlaylists();
  }

  async deletePlaylist(pid: number): Promise<void> {
    if (this.db === null) {
      return;
    }
    await this.db.executeSql(`DELETE FROM ${TABLE_REL} WHERE playlist_id = ${pid}`);
    await this.db.executeSql(`DELETE FROM ${TABLE_LIST} WHERE id = ${pid}`);
    await this.refreshPlaylists();
  }

  async addSongToPlaylist(pid: number, song: Song): Promise<void> {
    if (this.db === null || song.isRaw) {
      return; // 仅本地导入歌曲可入库（RDB 实验要求）
    }
    const songId: number = parseInt(song.key.substring('db:'.length), 10);
    await this.db.executeSql(
      `INSERT OR IGNORE INTO ${TABLE_REL}(playlist_id, song_id) VALUES(${pid}, ${songId})`);
    await this.refreshPlaylists();
  }

  async removeSongFromPlaylist(pid: number, song: Song): Promise<void> {
    if (this.db === null) {
      return;
    }
    const songId: number = parseInt(song.key.substring('db:'.length), 10);
    await this.db.executeSql(
      `DELETE FROM ${TABLE_REL} WHERE playlist_id = ${pid} AND song_id = ${songId}`);
    await this.refreshPlaylists();
  }

  // ---------------- 歌词 ----------------

  /** 加载歌词：内置歌曲读 rawfile/demo.lrc；导入歌曲暂无 LRC 时返回空数组 */
  async loadLrc(song: Song): Promise<LrcLine[]> {
    if (this.ctx === null) {
      return [];
    }
    if (song.isRaw) {
      try {
        const buf: Uint8Array = this.ctx.resourceManager.getRawFileContentSync('demo.lrc');
        const text: string = new util.TextDecoder('utf-8').decodeWithStream(buf);
        return parseLrc(text);
      } catch (e) {
        return [];
      }
    }
    // 导入歌曲：同名 .lrc 文件存在则解析（用户可在沙箱放入，扩展实验用）
    const dot: number = song.src.lastIndexOf('.');
    if (dot > 0) {
      const lrcPath: string = song.src.substring(0, dot) + '.lrc';
      try {
        const f: fileIo.File = fileIo.openSync(lrcPath, fileIo.OpenMode.READ_ONLY);
        const stat: fileIo.Stat = fileIo.statSync(f.fd);
        const buf: ArrayBuffer = new ArrayBuffer(stat.size);
        fileIo.readSync(f.fd, buf);
        fileIo.closeSync(f);
        const text: string = new util.TextDecoder('utf-8').decodeWithStream(new Uint8Array(buf));
        return parseLrc(text);
      } catch (e2) {
        return [];
      }
    }
    return [];
  }
}
