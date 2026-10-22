/**
 * LibraryPage.ets —— 音乐库页
 * 本地音乐导入（系统音频选择器 + ID3 元数据）、按歌名/歌手/专辑搜索、点击播放、加入歌单
 */
import { promptAction } from '@kit.ArkUI';
import { Song } from '../model/Song';
import { SongStore } from '../model/SongStore';
import { PlayerManager } from '../model/PlayerManager';
import { Theme, formatTime } from '../common/Theme';
import { CoverImage } from '../components/CoverImage';
import { AddToPlaylistDialog } from '../components/AddToPlaylistDialog';

@Component
export struct LibraryPage {
  @StorageLink('allSongs') allSongs: Song[] = [];
  @State keyword: string = '';
  @State importing: boolean = false;
  @State targetSong: Song = new Song('', '', '', '', 0, '', '', false);
  private dialogController: CustomDialogController = new CustomDialogController({
    builder: AddToPlaylistDialog({ song: this.targetSong }),
    alignment: DialogAlignment.Center,
    customStyle: true
  });

  private filteredSongs(): Song[] {
    const kw: string = this.keyword.trim().toLowerCase();
    if (kw.length === 0) {
      return this.allSongs;
    }
    return this.allSongs.filter((s: Song) =>
      s.title.toLowerCase().includes(kw) ||
      s.artist.toLowerCase().includes(kw) ||
      s.album.toLowerCase().includes(kw));
  }

  build() {
    Column() {
      // 标题与导入按钮
      Row() {
        Column() {
          Text('音乐库')
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor(Theme.TEXT)
          Text(`共 ${this.allSongs.length} 首`)
            .fontSize(12)
            .fontColor(Theme.MUTED)
            .margin({ top: 2 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Button(this.importing ? '导入中…' : '导入本地音乐')
          .height(38)
          .fontSize(13)
          .fontColor('#201633')
          .backgroundColor(Theme.GOLD)
          .enabled(!this.importing)
          .onClick(async () => {
            this.importing = true;
            try {
              const n: number = await SongStore.getInstance().importLocalAudio();
              if (n > 0) {
                promptAction.showToast({ message: `成功导入 ${n} 首本地音乐` });
              }
            } catch (e) {
              promptAction.showToast({ message: '导入失败，请重试' });
            }
            this.importing = false;
          })
      }
      .width('100%')
      .padding({ left: 18, right: 18, top: 16, bottom: 10 })

      // 搜索框
      Row({ space: 8 }) {
        Text('⌕')
          .fontSize(18)
          .fontColor(Theme.MUTED)
        TextInput({ placeholder: '搜索歌名 / 歌手 / 专辑', text: this.keyword })
          .layoutWeight(1)
          .height(38)
          .fontSize(14)
          .fontColor(Theme.TEXT)
          .placeholderColor(Theme.MUTED)
          .backgroundColor(Color.Transparent)
          .padding(0)
          .onChange((v: string) => {
            this.keyword = v;
          })
      }
      .width('92%')
      .height(42)
      .padding({ left: 14, right: 14 })
      .backgroundColor(Theme.CARD)
      .borderRadius(21)
      .margin({ bottom: 8 })

      // 歌曲列表
      Scroll() {
        Column({ space: 8 }) {
          ForEach(this.filteredSongs(), (song: Song, index: number) => {
            Row({ space: 12 }) {
              CoverImage({ song: song, imgSize: 48, round: false })
              Column({ space: 3 }) {
                Text(song.title)
                  .fontSize(15)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(Theme.TEXT)
                  .maxLines(1)
                Text(`${song.artist} · ${song.album}`)
                  .fontSize(12)
                  .fontColor(Theme.MUTED)
                  .maxLines(1)
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start)

              if (song.isRaw) {
                Text('内置')
                  .fontSize(10)
                  .fontColor(Theme.MUTED)
                  .border({ width: 1, color: Theme.MUTED })
                  .borderRadius(4)
                  .padding({ left: 6, right: 6, top: 2, bottom: 2 })
              } else {
                Text(formatTime(song.durationMs))
                  .fontSize(11)
                  .fontColor(Theme.MUTED)
                  .margin({ right: 4 })
                Button('+')
                  .width(30)
                  .height(30)
                  .fontSize(18)
                  .fontColor(Theme.GOLD)
                  .backgroundColor(Theme.CARD_2)
                  .onClick(() => {
                    this.targetSong = song;
                    this.dialogController.open();
                  })
              }
            }
            .width('100%')
            .padding(10)
            .backgroundColor(Theme.CARD)
            .borderRadius(12)
            .onClick(() => {
              PlayerManager.getInstance().setQueueAndPlay(this.filteredSongs(), index);
            })
          }, (song: Song) => song.key)
        }
        .width('92%')
        .padding({ bottom: 12 })
      }
      .layoutWeight(1)
      .align(Alignment.Top)
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Center)
  }
}
