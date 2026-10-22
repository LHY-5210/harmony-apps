/**
 * CoverImage.ets —— 统一的歌曲封面组件
 * 内置歌曲读 rawfile 封面；本地导入歌曲暂无封面时用默认专辑图。
 */
import { Song } from '../model/Song';
import { Theme } from '../common/Theme';

@Component
export struct CoverImage {
  @Prop song: Song | null = null;
  @Prop imgSize: number = 56;
  @Prop round: boolean = true;

  build() {
    Stack() {
      if (this.song !== null && this.song.isRaw && this.song.cover.length > 0) {
        Image($rawfile(this.song.cover))
          .width(this.imgSize)
          .height(this.imgSize)
          .borderRadius(this.round ? this.imgSize / 2 : 8)
          .objectFit(ImageFit.Cover)
      } else if (this.song !== null && !this.song.isRaw && this.song.cover.length > 0) {
        Image('file://' + this.song.cover)
          .width(this.imgSize)
          .height(this.imgSize)
          .borderRadius(this.round ? this.imgSize / 2 : 8)
          .objectFit(ImageFit.Cover)
      } else {
        Image($rawfile('cover_default.jpg'))
          .width(this.imgSize)
          .height(this.imgSize)
          .borderRadius(this.round ? this.imgSize / 2 : 8)
          .objectFit(ImageFit.Cover)
      }
    }
    .width(this.imgSize)
    .height(this.imgSize)
    .backgroundColor(Theme.CARD_2)
  }
}
