import { safeRedirectPath } from '../auth/redirect';

describe('safeRedirectPath', () => {
  it('giữ đường dẫn nội bộ', () => {
    expect(safeRedirectPath('/users?keyword=a')).toBe('/users?keyword=a');
    expect(safeRedirectPath('/foods/123')).toBe('/foods/123');
  });

  it('chặn đích ra ngoài hoặc không hợp lệ', () => {
    for (const bad of ['//evil.example', '/\\evil.example', '/\\/evil.example', '/foods\\..\\x', 'https://evil.example',
      'javascript:alert(1)', 'foods', '', '/foo\nbar', undefined, null, 42]) {
      expect(safeRedirectPath(bad)).toBe('/foods');
    }
  });
});
