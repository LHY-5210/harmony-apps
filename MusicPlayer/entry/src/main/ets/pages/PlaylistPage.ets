/**
 * PlaylistPage.ets —— 我的歌单页（RDB 持久化）
 * 新建/删除自定义歌单、展开查看歌曲、移除歌曲、点击播放整个歌单
 */
import { promptAction } from '@kit.ArkUI';
import { Song, Playlist } from '../model/Song';
import { SongStore } from '../model/SongStore';
import { PlayerManager } from '../model/PlayerManager';
import { Theme } from '../common/Theme';
import { CoverImage } from '../components/CoverImage';

@Component
export struct PlaylistPage {
  @StorageLink('playlists') playlists: Playlist[] = [];
  @State newName: string = '';
  @State expandedId: number = -1;

  build() {
    Column() {
      // 标题
      Row() {
        Text('我的歌单')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor(Theme.TEXT)
          .layoutWeight(1)
        Text(`共 ${this.playlists.length} 个`)
          .fontSize(12)
          .fontColor(Theme.MUTED)
      }
      .width('100%')
      .padding({ left: 18, right: 18, top: 16, bottom: 10 })

      // 新建歌单
      Row({ space: 10 }) {
        TextInput({ placeholder: '输入新歌单名称', text: this.newName })
          .layoutWeight(1)
          .height(40)
          .fontSize(14)
          .fontColor(Theme.TEXT)
          .placeholderColor(Theme.MUTED)
          .backgroundColor(Theme.CARD)
          .borderRadius(20)
          .padding({ left: 16, right: 16 })
          .onChange((v: string) => {
            this.newName = v;
          })
        Button('新建')
          .height(40)
          .fontSize(14)
          .fontColor('#201633')
          .backgroundColor(Theme.GOLD)
          .onClick(async () => {
            if (this.newName.trim().length === 0) {
              promptAction.showToast({ message: '歌单名不能为空' });
              return;
            }
            await SongStore.getInstance().createPlaylist(this.newName);
            this.newName = '';
            promptAction.showToast({ message: '歌单已创建' });
          })
      }
      .width('92%')
      .margin({ bottom: 10 })

      if (this.playlists.length === 0) {
        Column({ space: 10 }) {
          Text('♥')
            .fontSize(44)
            .fontColor(Theme.MUTED)
          Text('还没有歌单，先新建一个吧')
            .fontSize(14)
            .fontColor(Theme.MUTED)
          Text('（仅本地导入的歌曲可加入歌单）')
            .fontSize(12)
            .fontColor(Theme.MUTED)
        }
        .layoutWeight(1)
        .width('100%')
        .justifyContent(FlexAlign.Center)
      } else {
        Scroll() {
          Column({ space: 10 }) {
            ForEach(this.playlists, (pl: Playlist) => {
              Column() {
                // 歌单头
                Row({ space: 10 }) {
                  Text(this.expandedId === pl.id ? '▾' : '▸')
                    .fontSize(14)
                    .fontColor(Theme.GOLD)
                    .width(16)
                  Column({ space: 2 }) {
                    Text(pl.name)
                      .fontSize(16)
                      .fontWeight(FontWeight.Medium)
                      .fontColor(Theme.TEXT)
                    Text(`${pl.songs.length} 首`)
                      .fontSize(11)
                      .fontColor(Theme.MUTED)
                  }
                  .alignItems(HorizontalAlign.Start)
                  .layoutWeight(1)
                  Button('删除')
                    .height(30)
                    .fontSize(12)
                    .fontColor(Theme.DANGER)
                    .backgroundColor(Theme.CARD_2)
                    .onClick(() => {
                      SongStore.getInstance().deletePlaylist(pl.id);
                    })
                }
                .width('100%')
                .padding(12)
                .onClick(() => {
                  this.expandedId = this.expandedId === pl.id ? -1 : pl.id;
                })

                // 展开后的歌曲
                if (this.expandedId === pl.id) {
                  Column({ space: 6 }) {
                    if (pl.songs.length === 0) {
                      Text('歌单还是空的，去音乐库点“+”添加歌曲')
                        .fontSize(12)
                        .fontColor(Theme.MUTED)
                        .width('100%')
                        .padding(12)
                    } else {
                      ForEach(pl.songs, (song: Song, i: number) => {
                        Row({ space: 10 }) {
                          CoverImage({ song: song, imgSize: 38, round: false })
                          Column({ space: 2 }) {
                            Text(song.title)
                              .fontSize(14)
                              .fontColor(Theme.TEXT)
                              .maxLines(1)
                            Text(song.artist)
                              .fontSize(11)
                              .fontColor(Theme.MUTED)
                              .maxLines(1)
                          }
                          .layoutWeight(1)
                          .alignItems(HorizontalAlign.Start)
                          Button('移除')
                            .height(28)
                            .fontSize(11)
                            .fontColor(Theme.MUTED)
                            .backgroundColor(Theme.CARD_2)
                            .onClick(() => {
                              SongStore.getInstance().removeSongFromPlaylist(pl.id, song);
                            })
                        }
                        .width('100%')
                        .padding({ left: 12, right: 12, top: 6, bottom: 6 })
                        .onClick(() => {
                          PlayerManager.getInstance().setQueueAndPlay(pl.songs, i);
                        })
                      }, (song: Song) => `pl${pl.id}-${song.key}`)
                    }
                  }
                  .width('100%')
                  .padding({ bottom: 8 })
                }
              }
              .width('100%')
              .backgroundColor(Theme.CARD)
              .borderRadius(12)
            }, (pl: Playlist) => `playlist-${pl.id}`)
          }
          .width('92%')
          .padding({ bottom: 12 })
        }
        .layoutWeight(1)
        .align(Alignment.Top)
      }
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Center)
  }
}
