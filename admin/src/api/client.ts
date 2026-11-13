// API client cho trang quản trị (docs/31 §5).
// Token chỉ giữ trong bộ nhớ: tải lại trang thì đăng nhập lại (không lưu refresh token vào
// localStorage). Access token hết hạn → tự refresh đúng một lần rồi gửi lại request.

export interface ApiErrorBody {
  code?: string;
  message?: string;
  fieldErrors?: Record<string, string>;
  [key: string]: unknown;
}

export class ApiError extends Error {
  readonly status: number;
  readonly code: string;
  readonly fieldErrors: Record<string, string>;
  readonly body: ApiErrorBody;

  constructor(status: number, body: ApiErrorBody) {
    super(body.message ?? `Lỗi ${status}`);
    this.status = status;
    this.code = body.code ?? 'UNKNOWN';
    this.fieldErrors = body.fieldErrors ?? {};
    this.body = body;
  }
}

export interface SessionUser {
  id: string;
  email: string;
  fullName: string;
  role: 'USER' | 'ADMIN';
}

interface TokenResponse {
  accessToken: string;
  refreshToken: string;
  user: SessionUser;
}

interface Session {
  accessToken: string;
  refreshToken: string;
  user: SessionUser;
}

export const NOT_ADMIN = 'NOT_ADMIN';

type FetchFn = typeof fetch;

export class ApiClient {
  private session: Session | null = null;
  private refreshing: Promise<boolean> | null = null;
  private readonly listeners = new Set<(user: SessionUser | null) => void>();

  constructor(private readonly fetchFn: FetchFn = (...args) => fetch(...args)) {}

  get user(): SessionUser | null {
    return this.session?.user ?? null;
  }

  onSessionChange(listener: (user: SessionUser | null) => void): () => void {
    this.listeners.add(listener);
    return () => this.listeners.delete(listener);
  }

  /** Chỉ nhận ADMIN; USER đăng nhập được ở backend nhưng bị đăng xuất ngay ở đây. */
  async login(email: string, password: string): Promise<SessionUser> {
    const tokens = await this.send<TokenResponse>('POST', '/api/v1/auth/login', { email, password }, false);
    if (tokens.user.role !== 'ADMIN') {
      await this.revoke(tokens.refreshToken);
      throw new ApiError(403, { code: NOT_ADMIN, message: 'Tài khoản không có quyền quản trị' });
    }
    this.setSession({ accessToken: tokens.accessToken, refreshToken: tokens.refreshToken, user: tokens.user });
    return tokens.user;
  }

  async logout(): Promise<void> {
    const refresh = this.session?.refreshToken;
    this.setSession(null);
    if (refresh) await this.revoke(refresh);
  }

  get<T>(path: string): Promise<T> {
    return this.request<T>('GET', path);
  }

  post<T>(path: string, body: unknown): Promise<T> {
    return this.request<T>('POST', path, body);
  }

  put<T>(path: string, body: unknown): Promise<T> {
    return this.request<T>('PUT', path, body);
  }

  private async request<T>(method: string, path: string, body?: unknown): Promise<T> {
    try {
      return await this.send<T>(method, path, body, true);
    } catch (e) {
      // Access token hết hạn hoặc phiên bị thu hồi: thử refresh một lần.
      if (e instanceof ApiError && e.status === 401 && this.session && (await this.refresh())) {
        try {
          return await this.send<T>(method, path, body, true);
        } catch (retry) {
          if (retry instanceof ApiError && retry.status === 401) this.setSession(null);
          throw retry;
        }
      }
      // Bị khóa giữa chừng: kết thúc phiên ở client.
      if (e instanceof ApiError && (e.status === 401 || e.code === 'ACCOUNT_LOCKED')) this.setSession(null);
      throw e;
    }
  }

  /** Nhiều request cùng gặp 401 chỉ refresh một lần (refresh token xoay vòng, BR-A04). */
  private refresh(): Promise<boolean> {
    if (!this.refreshing) {
      const current = this.session;
      this.refreshing = (async () => {
        if (!current) return false;
        try {
          const tokens = await this.send<TokenResponse>('POST', '/api/v1/auth/refresh',
            { refreshToken: current.refreshToken }, false);
          if (tokens.user.role !== 'ADMIN') {
            this.setSession(null);
            return false;
          }
          this.setSession({ accessToken: tokens.accessToken, refreshToken: tokens.refreshToken, user: tokens.user });
          return true;
        } catch {
          this.setSession(null);
          return false;
        } finally {
          this.refreshing = null;
        }
      })();
    }
    return this.refreshing;
  }

  private async revoke(refreshToken: string): Promise<void> {
    try {
      await this.send('POST', '/api/v1/auth/logout', { refreshToken }, false);
    } catch {
      // Logout idempotent; lỗi mạng không chặn việc xóa phiên ở client.
    }
  }

  private async send<T>(method: string, path: string, body: unknown, auth: boolean): Promise<T> {
    const headers: Record<string, string> = { Accept: 'application/json' };
    if (body !== undefined) headers['Content-Type'] = 'application/json';
    if (auth && this.session) headers.Authorization = `Bearer ${this.session.accessToken}`;
    let response: Response;
    try {
      response = await this.fetchFn(path, {
        method,
        headers,
        body: body === undefined ? undefined : JSON.stringify(body),
      });
    } catch {
      throw new ApiError(0, { code: 'NETWORK_ERROR', message: 'Không kết nối được máy chủ' });
    }
    if (response.status === 204) return undefined as T;
    const text = await response.text();
    let json: unknown = undefined;
    if (text) {
      try {
        json = JSON.parse(text);
      } catch {
        json = undefined;
      }
    }
    if (!response.ok) {
      const errorBody = (json && typeof json === 'object' ? json : {}) as ApiErrorBody;
      throw new ApiError(response.status, errorBody);
    }
    return json as T;
  }

  private setSession(session: Session | null) {
    if (session === null && this.session === null) return;
    this.session = session;
    for (const listener of this.listeners) listener(session?.user ?? null);
  }
}

export const api = new ApiClient();

/** Thông báo chung cho lỗi không gắn với trường nào. */
export function describeError(e: unknown): string {
  if (e instanceof ApiError) {
    switch (e.code) {
      case 'VERSION_CONFLICT':
        return 'Dữ liệu đã được sửa ở nơi khác. Hãy tải lại rồi sửa tiếp.';
      case 'FORBIDDEN':
        return 'Bạn không có quyền thực hiện chức năng này.';
      case 'ACCOUNT_LOCKED':
        return 'Tài khoản đã bị khóa.';
      default:
        return e.message;
    }
  }
  return 'Đã có lỗi xảy ra';
}
