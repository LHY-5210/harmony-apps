import { HttpClient } from './HttpClient';
import { Item, Candidate, MatchPair, TimelineEvent, Appeal, CreditInfo, User } from '../../model/Types';

interface TokenResp { token: string; user: User; }
interface ClassifyResp { category: string; confidence: number; }
interface TextResp { text: string; }
interface NerResp { category: string; color: string; location: string; time: string; }
interface CreateItemResp { itemId: string; candidates?: Candidate[]; idempotent?: boolean; }
interface ItemListResp { items: Item[]; }
interface CandidateResp { candidates: Candidate[]; }
interface MatchListResp { matches: MatchPair[]; }
interface ClaimResp { claimId: number; status: string; }
interface VerifyResp { score: number; passed: boolean; }
interface ConfirmResp { winner: number; }
interface OkResp { ok: boolean; }
interface TimelineResp { events: TimelineEvent[]; }
interface AppealResp { appealId: number; }
interface AppealListResp { appeals: Appeal[]; }
interface UserListResp { users: User[]; }
interface SyncResp { items: Item[]; timestamp: number; }

export class ApiService {
  static login(username: string, password: string): Promise<TokenResp> {
    return HttpClient.send<TokenResp>('POST', '/api/auth/token',
      JSON.stringify({ username: username, password: password }));
  }

  static async register(username: string, password: string): Promise<void> {
    await HttpClient.send('POST', '/api/auth/register',
      JSON.stringify({ username: username, password: password }));
  }

  static me(): Promise<User> {
    return HttpClient.get<User>('/api/auth/me');
  }

  static classify(image: string): Promise<ClassifyResp> {
    return HttpClient.send<ClassifyResp>('POST', '/api/ai/classify', JSON.stringify({ image: image }));
  }

  static ocr(image: string): Promise<TextResp> {
    return HttpClient.send<TextResp>('POST', '/api/ai/ocr', JSON.stringify({ image: image }));
  }

  static asr(audio: string): Promise<TextResp> {
    return HttpClient.send<TextResp>('POST', '/api/ai/asr', JSON.stringify({ audio: audio }));
  }

  static ner(text: string): Promise<NerResp> {
    return HttpClient.send<NerResp>('POST', '/api/ai/ner', JSON.stringify({ text: text }));
  }

  static createItem(item: Item): Promise<CreateItemResp> {
    return HttpClient.send<CreateItemResp>('POST', '/api/items', JSON.stringify({
      itemId: item.itemId,
      type: item.type,
      category: item.category,
      color: item.color,
      location: item.location,
      eventTime: item.eventTime,
      description: item.description,
      ocrText: item.ocrText,
      imageUrl: item.imageUrl,
      credentialQuestion: item.credentialQuestion,
      credentialAnswer: item.credentialAnswer
    }));
  }

  static listItems(type: string, category: string, page: number): Promise<ItemListResp> {
    let qs: string = 'page=' + page;
    if (type.length > 0) {
      qs += '&type=' + encodeURIComponent(type);
    }
    if (category.length > 0) {
      qs += '&category=' + encodeURIComponent(category);
    }
    return HttpClient.get<ItemListResp>('/api/items?' + qs);
  }

  static myItems(): Promise<ItemListResp> {
    return HttpClient.get<ItemListResp>('/api/items/mine');
  }

  static getItem(itemId: string): Promise<Item> {
    return HttpClient.get<Item>('/api/items/' + itemId);
  }

  static candidates(itemId: string): Promise<CandidateResp> {
    return HttpClient.get<CandidateResp>('/api/items/' + itemId + '/candidates');
  }

  static listMatches(itemId: string): Promise<MatchListResp> {
    if (itemId.length > 0) {
      return HttpClient.get<MatchListResp>('/api/matches?item_id=' + encodeURIComponent(itemId));
    }
    return HttpClient.get<MatchListResp>('/api/matches');
  }

  static claim(matchId: number): Promise<ClaimResp> {
    return HttpClient.send<ClaimResp>('POST', '/api/matches/' + matchId + '/claim');
  }

  static verifyClaim(claimId: number, answer: string): Promise<VerifyResp> {
    return HttpClient.send<VerifyResp>('POST', '/api/claims/' + claimId + '/verify',
      JSON.stringify({ answer: answer }));
  }

  static confirm(matchId: number): Promise<ConfirmResp> {
    return HttpClient.send<ConfirmResp>('POST', '/api/matches/' + matchId + '/confirm');
  }

  static closeMatch(matchId: number): Promise<OkResp> {
    return HttpClient.send<OkResp>('POST', '/api/matches/' + matchId + '/close');
  }

  static timeline(matchId: number): Promise<TimelineResp> {
    return HttpClient.get<TimelineResp>('/api/matches/' + matchId + '/timeline');
  }

  static appeal(matchId: number, evidenceLevel: number, evidenceText: string): Promise<AppealResp> {
    return HttpClient.send<AppealResp>('POST', '/api/matches/' + matchId + '/appeal',
      JSON.stringify({ evidenceLevel: evidenceLevel, evidenceText: evidenceText }));
  }

  static decideAppeal(appealId: number, result: string): Promise<OkResp> {
    return HttpClient.send<OkResp>('POST', '/api/appeals/' + appealId + '/decide',
      JSON.stringify({ result: result }));
  }

  static myCredit(): Promise<CreditInfo> {
    return HttpClient.get<CreditInfo>('/api/me/credit');
  }

  static adminStats(): Promise<Record<string, number>> {
    return HttpClient.get('/api/admin/stats');
  }

  static adminAppeals(): Promise<AppealListResp> {
    return HttpClient.get<AppealListResp>('/api/admin/appeals');
  }

  static adminBanned(): Promise<UserListResp> {
    return HttpClient.get<UserListResp>('/api/admin/banned');
  }

  static syncItems(since: number): Promise<SyncResp> {
    return HttpClient.get<SyncResp>('/api/sync/items?since=' + since);
  }
}
