import { describe, expect, it, vi } from 'vitest';
import { ApiClient, ApiError, NOT_ADMIN, describeError } from '../api/client';

type Handler = (url: string, init: RequestInit) => Response | Promise<Response>;

function json(status: number, body?: unknown): Response {
  return new Response(body === undefined ? null : JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

function tokens(role: 'ADMIN' | 'USER', n: number) {
  return {
    accessToken: `access-${n}`,
    refreshToken: `refresh-${n}`,
    user: { id: 'u1', email: 'a@x.vn', fullName: 'A', role },
  };
}

function client(handler: Handler) {
  const calls: { url: string; init: RequestInit }[] = [];
  const fetchFn = vi.fn(async (url: RequestInfo | URL, init?: RequestInit) => {
    calls.push({ url: String(url), init: init ?? {} });
    return handler(String(url), init ?? {});
  });
  return { api: new ApiClient(fetchFn as unknown as typeof fetch), calls };
}

const auth = (init: RequestInit) => (init.headers as Record<string, string>).Authorization;

describe('ApiClient', () => {
  it('chỉ nhận tài khoản ADMIN và thu hồi phiên USER vừa tạo', async () => {
    const { api, calls } = client((url) =>
      url.endsWith('/auth/login') ? json(200, tokens('USER', 1)) : json(204));
    await expect(api.login('u@x.vn', 'Matkhau123')).rejects.toMatchObject({ code: NOT_ADMIN, status: 403 });
    expect(api.user).toBeNull();
    expect(calls.map((c) => c.url)).toEqual(['/api/v1/auth/login', '/api/v1/auth/logout']);
    expect(JSON.parse(String(calls[1].init.body))).toEqual({ refreshToken: 'refresh-1' });
  });

  it('gửi Bearer và refresh đúng một lần khi nhiều request cùng gặp 401', async () => {
    let refreshes = 0;
    const { api, calls } = client((url, init) => {
      if (url.endsWith('/auth/login')) return json(200, tokens('ADMIN', 1));
      if (url.endsWith('/auth/refresh')) {
        refreshes++;
        return json(200, tokens('ADMIN', 2));
      }
      return auth(init) === 'Bearer access-2' ? json(200, { ok: true }) : json(401, { code: 'UNAUTHORIZED' });
    });
    await api.login('a@x.vn', 'Matkhau123');
    const results = await Promise.all([api.get('/api/v1/admin/foods'), api.get('/api/v1/admin/users')]);
    expect(results).toEqual([{ ok: true }, { ok: true }]);
    expect(refreshes).toBe(1);
    const refreshCall = calls.find((c) => c.url.endsWith('/auth/refresh'))!;
    expect(JSON.parse(String(refreshCall.init.body))).toEqual({ refreshToken: 'refresh-1' });
    expect(auth(refreshCall.init)).toBeUndefined();
  });

  it('refresh thất bại (phiên bị thu hồi khi khóa) thì kết thúc phiên', async () => {
    const seen: (string | null)[] = [];
    const { api } = client((url) => {
      if (url.endsWith('/auth/login')) return json(200, tokens('ADMIN', 1));
      if (url.endsWith('/auth/refresh')) return json(401, { code: 'INVALID_REFRESH_TOKEN' });
      return json(401, { code: 'UNAUTHORIZED' });
    });
    api.onSessionChange((u) => seen.push(u?.email ?? null));
    await api.login('a@x.vn', 'Matkhau123');
    await expect(api.get('/api/v1/admin/foods')).rejects.toBeInstanceOf(ApiError);
    expect(api.user).toBeNull();
    expect(seen).toEqual(['a@x.vn', null]);
  });

  it('403 FORBIDDEN không refresh và không đăng xuất', async () => {
    const { api, calls } = client((url) =>
      url.endsWith('/auth/login') ? json(200, tokens('ADMIN', 1))
        : json(403, { code: 'FORBIDDEN', message: 'Bạn không có quyền thực hiện chức năng này' }));
    await api.login('a@x.vn', 'Matkhau123');
    await expect(api.get('/api/v1/admin/foods')).rejects.toMatchObject({ status: 403, code: 'FORBIDDEN' });
    expect(api.user).not.toBeNull();
    expect(calls.some((c) => c.url.endsWith('/auth/refresh'))).toBe(false);
  });

  it('giữ fieldErrors và trường thêm của body lỗi (409 VERSION_CONFLICT)', async () => {
    const { api } = client((url) => {
      if (url.endsWith('/auth/login')) return json(200, tokens('ADMIN', 1));
      if (url.includes('/foods/1')) return json(409, { code: 'VERSION_CONFLICT', message: 'x', currentRevision: 3 });
      return json(400, { code: 'VALIDATION_ERROR', message: 'Dữ liệu không hợp lệ', fieldErrors: { source: 'Thiếu' } });
    });
    await api.login('a@x.vn', 'Matkhau123');
    const conflict = (await api.put('/api/v1/admin/foods/1', {}).catch((e) => e)) as ApiError;
    expect(conflict.body.currentRevision).toBe(3);
    expect(describeError(conflict)).toContain('tải lại');
    const invalid = (await api.post('/api/v1/admin/foods', {}).catch((e) => e)) as ApiError;
    expect(invalid.fieldErrors).toEqual({ source: 'Thiếu' });
  });

  it('lỗi mạng thành NETWORK_ERROR; logout xóa phiên kể cả khi máy chủ lỗi', async () => {
    let down = false;
    const { api } = client((url) => {
      if (down) throw new TypeError('Failed to fetch');
      return url.endsWith('/auth/login') ? json(200, tokens('ADMIN', 1)) : json(200, {});
    });
    await api.login('a@x.vn', 'Matkhau123');
    down = true;
    await expect(api.get('/api/v1/admin/foods')).rejects.toMatchObject({ code: 'NETWORK_ERROR' });
    await api.logout();
    expect(api.user).toBeNull();
  });
});
