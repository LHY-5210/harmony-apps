import { HttpClient } from './HttpClient';
import preferences from '@ohos.data.preferences';
import { User } from '../../model/Types';

interface LoginResp {
  token: string;
  expiresIn: number;
  user: User;
}

const PREF_NAME: string = 'lostfound_auth';
const KEY_TOKEN: string = 'token';
const KEY_USER: string = 'user';

export class AuthService {
  private static store: preferences.Preferences | null = null;

  private static async getStore(): Promise<preferences.Preferences> {
    if (AuthService.store === null) {
      AuthService.store = await preferences.getPreferences(getContext(), PREF_NAME);
    }
    return AuthService.store;
  }

  static async login(username: string, password: string): Promise<User> {
    const data: LoginResp = await HttpClient.send<LoginResp>('POST', '/api/auth/token',
      JSON.stringify({ username: username, password: password }));
    const store = await AuthService.getStore();
    await store.put(KEY_TOKEN, data.token);
    await store.put(KEY_USER, JSON.stringify(data.user));
    await store.flush();
    return data.user;
  }

  static async register(username: string, password: string): Promise<void> {
    await HttpClient.send('POST', '/api/auth/register',
      JSON.stringify({ username: username, password: password }));
  }

  static async getToken(): Promise<string> {
    const store = await AuthService.getStore();
    return (await store.get(KEY_TOKEN, '')) as string;
  }

  static async getUser(): Promise<User | null> {
    const store = await AuthService.getStore();
    const raw = await store.get(KEY_USER, '');
    if (raw === '') {
      return null;
    }
    try {
      return JSON.parse(raw as string) as User;
    } catch (e) {
      return null;
    }
  }

  static async logout(): Promise<void> {
    const store = await AuthService.getStore();
    await store.delete(KEY_TOKEN);
    await store.delete(KEY_USER);
    await store.flush();
  }

  static async isLoggedIn(): Promise<boolean> {
    return (await AuthService.getToken()) !== '';
  }
}
