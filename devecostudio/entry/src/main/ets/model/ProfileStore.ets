// 项目信息 + 个人信息的本地持久化存储（Preferences）+ AppStorage 全局共享
import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';

// 默认值
const DEFAULT_PROJECT_TITLE: string = '电子名片与任务管理';
const DEFAULT_PROJECT_SUBTITLE: string = 'HarmonyOS ArkTS 课程实践项目';
const DEFAULT_NAME: string = '张同学';
const DEFAULT_STUDENT_ID: string = '20240001';
const DEFAULT_CLASS: string = '计算机科学与技术 1 班';
const DEFAULT_COLLEGE: string = '信息工程学院';

// AppStorage 的 key（主页面与编辑页共享，编辑后主页面立即更新）
export const KEY_PROJECT_TITLE: string = 'profile_projectTitle';
export const KEY_PROJECT_SUBTITLE: string = 'profile_projectSubtitle';
export const KEY_NAME: string = 'profile_name';
export const KEY_STUDENT_ID: string = 'profile_studentId';
export const KEY_CLASS_NAME: string = 'profile_className';
export const KEY_COLLEGE: string = 'profile_college';

const STORE_NAME: string = 'user_profile';

export class ProfileInfo {
  projectTitle: string = DEFAULT_PROJECT_TITLE;
  projectSubtitle: string = DEFAULT_PROJECT_SUBTITLE;
  name: string = DEFAULT_NAME;
  studentId: string = DEFAULT_STUDENT_ID;
  className: string = DEFAULT_CLASS;
  college: string = DEFAULT_COLLEGE;
}

export class ProfileStore {
  // 在应用启动时调用：从本地 preferences 读取并写入 AppStorage，供全应用共享
  static async initAppStorage(context: common.UIAbilityContext): Promise<void> {
    const prefs: preferences.Preferences =
      await preferences.getPreferences(context, STORE_NAME);
    AppStorage.setOrCreate(KEY_PROJECT_TITLE, String(prefs.getSync('projectTitle', DEFAULT_PROJECT_TITLE)));
    AppStorage.setOrCreate(KEY_PROJECT_SUBTITLE, String(prefs.getSync('projectSubtitle', DEFAULT_PROJECT_SUBTITLE)));
    AppStorage.setOrCreate(KEY_NAME, String(prefs.getSync('name', DEFAULT_NAME)));
    AppStorage.setOrCreate(KEY_STUDENT_ID, String(prefs.getSync('studentId', DEFAULT_STUDENT_ID)));
    AppStorage.setOrCreate(KEY_CLASS_NAME, String(prefs.getSync('className', DEFAULT_CLASS)));
    AppStorage.setOrCreate(KEY_COLLEGE, String(prefs.getSync('college', DEFAULT_COLLEGE)));
  }

  // 保存到本地 preferences（同时 AppStorage 已由页面通过 @StorageLink 同步更新）
  static async save(context: common.UIAbilityContext): Promise<void> {
    const prefs: preferences.Preferences =
      await preferences.getPreferences(context, STORE_NAME);
    prefs.putSync('projectTitle', AppStorage.get<string>(KEY_PROJECT_TITLE) ?? DEFAULT_PROJECT_TITLE);
    prefs.putSync('projectSubtitle', AppStorage.get<string>(KEY_PROJECT_SUBTITLE) ?? DEFAULT_PROJECT_SUBTITLE);
    prefs.putSync('name', AppStorage.get<string>(KEY_NAME) ?? DEFAULT_NAME);
    prefs.putSync('studentId', AppStorage.get<string>(KEY_STUDENT_ID) ?? DEFAULT_STUDENT_ID);
    prefs.putSync('className', AppStorage.get<string>(KEY_CLASS_NAME) ?? DEFAULT_CLASS);
    prefs.putSync('college', AppStorage.get<string>(KEY_COLLEGE) ?? DEFAULT_COLLEGE);
    await prefs.flush();
  }
}
