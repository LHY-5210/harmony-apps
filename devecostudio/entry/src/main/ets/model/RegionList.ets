// 省市数据：内置省-市两级列表及经纬度坐标（坐标用于天气查询）
// 天气查询只依赖经纬度，数据内置可离线选择城市，避免额外的地名解析请求

export class CityCoord {
  name: string;
  lat: number;
  lon: number;

  constructor(name: string, lat: number, lon: number) {
    this.name = name;
    this.lat = lat;
    this.lon = lon;
  }
}

export class Province {
  name: string;
  cities: CityCoord[];

  constructor(name: string, cities: CityCoord[]) {
    this.name = name;
    this.cities = cities;
  }
}

export function buildProvinces(): Province[] {
  const list: Province[] = [];
  list.push(new Province('北京市', [new CityCoord('北京', 39.90, 116.41)]));
  list.push(new Province('天津市', [new CityCoord('天津', 39.08, 117.20)]));
  list.push(new Province('上海市', [new CityCoord('上海', 31.23, 121.47)]));
  list.push(new Province('重庆市', [new CityCoord('重庆', 29.56, 106.55)]));
  list.push(new Province('河北省', [
    new CityCoord('石家庄', 38.04, 114.51),
    new CityCoord('保定', 38.87, 115.46),
    new CityCoord('唐山', 39.63, 118.18),
    new CityCoord('秦皇岛', 39.94, 119.60),
    new CityCoord('张家口', 40.77, 114.88)
  ]));
  list.push(new Province('山西省', [
    new CityCoord('太原', 37.87, 112.55),
    new CityCoord('大同', 40.08, 113.30),
    new CityCoord('临汾', 36.08, 111.52),
    new CityCoord('运城', 35.03, 111.00)
  ]));
  list.push(new Province('内蒙古自治区', [
    new CityCoord('呼和浩特', 40.84, 111.75),
    new CityCoord('包头', 40.66, 109.84),
    new CityCoord('鄂尔多斯', 39.61, 109.78),
    new CityCoord('呼伦贝尔', 49.21, 119.77)
  ]));
  list.push(new Province('辽宁省', [
    new CityCoord('沈阳', 41.80, 123.43),
    new CityCoord('大连', 38.91, 121.61),
    new CityCoord('鞍山', 41.11, 122.99),
    new CityCoord('锦州', 41.10, 121.13)
  ]));
  list.push(new Province('吉林省', [
    new CityCoord('长春', 43.82, 125.32),
    new CityCoord('吉林', 43.84, 126.55),
    new CityCoord('延边', 42.91, 129.51),
    new CityCoord('松原', 45.14, 124.83)
  ]));
  list.push(new Province('黑龙江省', [
    new CityCoord('哈尔滨', 45.80, 126.53),
    new CityCoord('齐齐哈尔', 47.35, 123.92),
    new CityCoord('牡丹江', 44.55, 129.63),
    new CityCoord('大庆', 46.59, 125.10)
  ]));
  list.push(new Province('江苏省', [
    new CityCoord('南京', 32.06, 118.80),
    new CityCoord('苏州', 31.30, 120.58),
    new CityCoord('无锡', 31.49, 120.31),
    new CityCoord('扬州', 32.39, 119.41),
    new CityCoord('徐州', 34.20, 117.28)
  ]));
  list.push(new Province('浙江省', [
    new CityCoord('杭州', 30.27, 120.16),
    new CityCoord('宁波', 29.87, 121.54),
    new CityCoord('温州', 28.00, 120.70),
    new CityCoord('义乌', 29.31, 120.08),
    new CityCoord('舟山', 29.99, 122.21)
  ]));
  list.push(new Province('安徽省', [
    new CityCoord('合肥', 31.82, 117.23),
    new CityCoord('芜湖', 31.33, 118.38),
    new CityCoord('黄山', 29.71, 118.34),
    new CityCoord('安庆', 30.54, 117.05)
  ]));
  list.push(new Province('福建省', [
    new CityCoord('福州', 26.07, 119.31),
    new CityCoord('厦门', 24.48, 118.09),
    new CityCoord('泉州', 24.87, 118.68),
    new CityCoord('武夷山', 27.76, 118.03)
  ]));
  list.push(new Province('江西省', [
    new CityCoord('南昌', 28.68, 115.86),
    new CityCoord('九江', 29.71, 116.00),
    new CityCoord('赣州', 25.83, 114.93),
    new CityCoord('景德镇', 29.27, 117.18)
  ]));
  list.push(new Province('山东省', [
    new CityCoord('济南', 36.65, 117.12),
    new CityCoord('青岛', 36.07, 120.38),
    new CityCoord('烟台', 37.54, 121.39),
    new CityCoord('威海', 37.51, 122.12),
    new CityCoord('泰安', 36.20, 117.11)
  ]));
  list.push(new Province('河南省', [
    new CityCoord('郑州', 34.75, 113.63),
    new CityCoord('洛阳', 34.62, 112.45),
    new CityCoord('开封', 34.80, 114.31),
    new CityCoord('信阳', 32.15, 114.07)
  ]));
  list.push(new Province('湖北省', [
    new CityCoord('武汉', 30.59, 114.31),
    new CityCoord('宜昌', 30.69, 111.29),
    new CityCoord('襄阳', 32.04, 112.12),
    new CityCoord('十堰', 32.63, 110.80)
  ]));
  list.push(new Province('湖南省', [
    new CityCoord('长沙', 28.23, 112.94),
    new CityCoord('张家界', 29.12, 110.48),
    new CityCoord('岳阳', 29.36, 113.13),
    new CityCoord('衡阳', 26.89, 112.61)
  ]));
  list.push(new Province('广东省', [
    new CityCoord('广州', 23.13, 113.26),
    new CityCoord('深圳', 22.54, 114.06),
    new CityCoord('珠海', 22.27, 113.58),
    new CityCoord('汕头', 23.35, 116.68),
    new CityCoord('湛江', 21.27, 110.36)
  ]));
  list.push(new Province('广西壮族自治区', [
    new CityCoord('南宁', 22.82, 108.32),
    new CityCoord('桂林', 25.28, 110.29),
    new CityCoord('北海', 21.48, 109.12),
    new CityCoord('柳州', 24.33, 109.42)
  ]));
  list.push(new Province('海南省', [
    new CityCoord('海口', 20.04, 110.34),
    new CityCoord('三亚', 18.25, 109.51),
    new CityCoord('儋州', 19.52, 109.58)
  ]));
  list.push(new Province('四川省', [
    new CityCoord('成都', 30.57, 104.07),
    new CityCoord('绵阳', 31.47, 104.68),
    new CityCoord('乐山', 29.55, 103.77),
    new CityCoord('九寨沟', 33.26, 103.92),
    new CityCoord('攀枝花', 26.58, 101.72)
  ]));
  list.push(new Province('贵州省', [
    new CityCoord('贵阳', 26.65, 106.63),
    new CityCoord('遵义', 27.73, 107.03),
    new CityCoord('六盘水', 26.59, 104.83)
  ]));
  list.push(new Province('云南省', [
    new CityCoord('昆明', 25.04, 102.71),
    new CityCoord('大理', 25.61, 100.27),
    new CityCoord('丽江', 26.86, 100.23),
    new CityCoord('西双版纳', 22.01, 100.80)
  ]));
  list.push(new Province('西藏自治区', [
    new CityCoord('拉萨', 29.65, 91.14),
    new CityCoord('日喀则', 29.27, 88.88),
    new CityCoord('林芝', 29.65, 94.36)
  ]));
  list.push(new Province('陕西省', [
    new CityCoord('西安', 34.34, 108.94),
    new CityCoord('宝鸡', 34.36, 107.24),
    new CityCoord('延安', 36.59, 109.49),
    new CityCoord('汉中', 33.07, 107.02)
  ]));
  list.push(new Province('甘肃省', [
    new CityCoord('兰州', 36.06, 103.83),
    new CityCoord('敦煌', 40.14, 94.66),
    new CityCoord('天水', 34.58, 105.72),
    new CityCoord('酒泉', 39.73, 98.49)
  ]));
  list.push(new Province('青海省', [
    new CityCoord('西宁', 36.62, 101.78),
    new CityCoord('海东', 36.50, 102.10),
    new CityCoord('格尔木', 36.40, 94.90)
  ]));
  list.push(new Province('宁夏回族自治区', [
    new CityCoord('银川', 38.49, 106.23),
    new CityCoord('石嘴山', 38.98, 106.38),
    new CityCoord('中卫', 37.51, 105.19)
  ]));
  list.push(new Province('新疆维吾尔自治区', [
    new CityCoord('乌鲁木齐', 43.83, 87.62),
    new CityCoord('喀什', 39.47, 75.99),
    new CityCoord('伊犁', 43.92, 81.28),
    new CityCoord('吐鲁番', 42.95, 89.19)
  ]));
  list.push(new Province('香港特别行政区', [new CityCoord('香港', 22.32, 114.17)]));
  list.push(new Province('澳门特别行政区', [new CityCoord('澳门', 22.20, 113.55)]));
  list.push(new Province('台湾省', [
    new CityCoord('台北', 25.03, 121.57),
    new CityCoord('高雄', 22.63, 120.30)
  ]));
  return list;
}
