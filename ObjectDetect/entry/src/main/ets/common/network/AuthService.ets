import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { HttpResp, HttpClient } from './HttpClient';

interface TokenResp {
  token: string;
  expiresIn: number;
}

// 设备标识 + 密钥换 JWT，缓存过期前自动刷新
export class AuthService {
  private static token: string = '';
  private static expAt: number = 0;
  private static deviceId: string = '';
  private static readonly secret: string = 'objectdetect-2026';
  private static readonly PREF: string = 'auth_pref';

  static async init(ctx: common.Context): Promise<void> {
    if (AuthService.deviceId.length > 0) {
      return;
    }
    const store: preferences.Preferences = await preferences.getPreferences(ctx, AuthService.PREF);
    let id: string = await store.get('deviceId', '') as string;
    if (id.length === 0) {
      id = `emu-${Date.now()}`;
      await store.put('deviceId', id);
      await store.flush();
    }
    AuthService.deviceId = id;
  }

  static getDeviceId(): string {
    return AuthService.deviceId;
  }

  static isLoggedIn(): boolean {
    return AuthService.token.length > 0 && Date.now() < AuthService.expAt;
  }

  // 收到 401 时丢弃本地缓存，强制重新换 token
  static invalidate(): void {
    AuthService.token = '';
    AuthService.expAt = 0;
  }

  static async ensureToken(): Promise<string> {
    if (AuthService.isLoggedIn()) {
      return AuthService.token;
    }
    if (AuthService.token.length > 0) {
      try {
        return await AuthService.refresh();
      } catch (e) {
        // 刷新失败则重新登录
      }
    }
    return await AuthService.login();
  }

  private static async login(): Promise<string> {
    const body: string = JSON.stringify({ deviceId: AuthService.deviceId, secret: AuthService.secret });
    const res: HttpResp = await HttpClient.send('POST', '/api/auth/token', body, '');
    if (res.code !== 200) {
      throw new Error(`login failed ${res.code}`);
    }
    return AuthService.store(TokenRespFrom(res.body));
  }

  private static async refresh(): Promise<string> {
    const res: HttpResp = await HttpClient.send('POST', '/api/auth/refresh', '', AuthService.token);
    if (res.code !== 200) {
      throw new Error(`refresh failed ${res.code}`);
    }
    return AuthService.store(TokenRespFrom(res.body));
  }

  private static store(r: TokenResp): string {
    AuthService.token = r.token;
    AuthService.expAt = Date.now() + r.expiresIn * 1000;
    return AuthService.token;
  }
}

function TokenRespFrom(body: string): TokenResp {
  const r: TokenResp = JSON.parse(body) as TokenResp;
  return r;
}
