// 公共小组件：表单输入行（标签 + 输入框）
@Component
export struct FieldRow {
  @Link value: string;
  label: string = '';
  placeholder: string = '';
  onChange?: () => void;

  build() {
    Row({ space: 10 }) {
      Text(this.label).fontSize(14).fontColor('#666666').width(64)
      TextInput({ text: this.value, placeholder: this.placeholder })
        .layoutWeight(1).height(42)
        .backgroundColor('#F5F6F8').borderRadius(8)
        .onChange((v: string) => {
          this.value = v;
          if (this.onChange !== undefined) {
            this.onChange();
          }
        })
    }
    .width('100%')
  }
}
