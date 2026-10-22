@Component
export struct AboutPage {
  build() {
    Scroll() {
      Column({ space: 14 }) {
        Text('人体解剖台')
          .fontSize(24).fontWeight(FontWeight.Bold)
          .fontColor(Color.White).margin({ top: 20 })
        Text('Open-source 3D anatomy explorer')
          .fontSize(12).fontColor('#888').fontStyle(FontStyle.Italic)

        Column({ space: 8 }) {
          Text('项目说明')
            .fontSize(16).fontWeight(FontWeight.Bold).fontColor('#56d4a7')
          Text('本应用将开源项目 Human Atlas 移植到鸿蒙，采用 ArkWeb + ArkTS 混合架构，实现 3D 解剖浏览、收藏、历史与笔记功能。')
            .fontSize(13).fontColor('#ccc').lineHeight(20)
        }
        .width('100%').padding(14).backgroundColor('#1e2440').borderRadius(10)

        Column({ space: 8 }) {
          Text('应用代码许可')
            .fontSize(16).fontWeight(FontWeight.Bold).fontColor('#56d4a7')
          Text('MIT License © ashemag')
            .fontSize(13).fontColor('#ccc').lineHeight(20)
          Text('移植版本保留原始许可声明。')
            .fontSize(11).fontColor('#888')
        }
        .width('100%').padding(14).backgroundColor('#1e2440').borderRadius(10)

        Column({ space: 8 }) {
          Text('解剖数据许可 ⚠️ CC BY 4.0')
            .fontSize(16).fontWeight(FontWeight.Bold).fontColor('#ffc46a')
          Text('BodyParts3D, © The Database Center for Life Science licensed under CC Attribution 4.0 International.')
            .fontSize(13).fontColor('#ccc').lineHeight(20)
          Text('本应用移植时分发时必须保留此署名信息。数据集来源：\nhttps://dbarchive.biosciencedbc.jp/en/bodyparts3d/')
            .fontSize(11).fontColor('#aaa').lineHeight(18)
        }
        .width('100%').padding(14).backgroundColor('#1e2440').borderRadius(10)

        Column({ space: 8 }) {
          Text('免责声明')
            .fontSize(16).fontWeight(FontWeight.Bold).fontColor('#ff8899')
          Text('本应用为解剖学教育探索工具，不包含所有人类结构或变异。彩色和系统分组仅用于探索。几何数据为 Web 端简化版本，简短说明提供一般教育背景。这是解剖学参考，不是诊断或手术工具。')
            .fontSize(12).fontColor('#ccc').lineHeight(20)
        }
        .width('100%').padding(14).backgroundColor('#1e2440').borderRadius(10)

        Column({ space: 4 }) {
          Text('技术栈')
            .fontSize(14).fontWeight(FontWeight.Bold).fontColor('#aaa')
          Text('Web：React + Three.js + shadcn/ui + Vite\n鸿蒙：ArkWeb + ArkTS + RDB 关系型数据库')
            .fontSize(11).fontColor('#888').lineHeight(16)
        }
        .width('100%').padding({ top: 10, bottom: 20 })
      }
      .width('100%').padding({ left: 18, right: 18 })
    }
    .width('100%').height('100%').backgroundColor('#0f1222')
  }
}
