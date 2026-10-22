/**
 * AddToPlaylistDialog.ets —— 把歌曲加入自定义歌单的选择对话框
 */
import { Song, Playlist } from '../model/Song';
import { SongStore } from '../model/SongStore';
import { Theme } from '../common/Theme';

@CustomDialog
export struct AddToPlaylistDialog {
  @Prop song: Song = new Song('', '', '', '', 0, '', '', true);
  controller: CustomDialogController = new CustomDialogController({ builder: AddToPlaylistDialog({}) });
  @StorageLink('playlists') playlists: Playlist[] = [];

  build() {
    Column() {
      Text('添加到歌单')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(Theme.TEXT)
        .margin({ bottom: 12 })

      if (this.playlists.length === 0) {
        Text('还没有歌单，请先到“我的歌单”页新建一个')
          .fontSize(14)
          .fontColor(Theme.MUTED)
          .textAlign(TextAlign.Center)
          .margin({ bottom: 16 })
      } else {
        Scroll() {
          Column({ space: 10 }) {
            ForEach(this.playlists, (pl: Playlist) => {
              Button(pl.name)
                .width('100%')
                .height(42)
                .fontSize(15)
                .fontColor(Theme.TEXT)
                .backgroundColor(Theme.CARD_2)
                .onClick(() => {
                  SongStore.getInstance().addSongToPlaylist(pl.id, this.song);
                  this.controller.close();
                })
            }, (pl: Playlist) => `pl-${pl.id}`)
          }
          .width('100%')
        }
        .constraintSize({ maxHeight: 240 })
        .margin({ bottom: 8 })
      }

      Button('取消')
        .width('100%')
        .height(40)
        .fontSize(15)
        .fontColor(Theme.MUTED)
        .backgroundColor(Color.Transparent)
        .onClick(() => {
          this.controller.close();
        })
    }
    .width('86%')
    .padding(20)
    .backgroundColor(Theme.CARD)
    .borderRadius(16)
  }
}
