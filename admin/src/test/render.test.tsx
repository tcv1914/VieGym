import { cleanup, render, screen, waitFor } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { api } from '../api/client';
import { FoodsPage } from '../pages/FoodsPage';

afterEach(() => {
  cleanup();
  vi.restoreAllMocks();
});

const XSS = '<img src=x onerror="window.__xss=1"> Phở';

describe('AD08 — dữ liệu có ký tự HTML', () => {
  it('hiển thị tên món dạng chữ, không tạo phần tử HTML', async () => {
    vi.spyOn(api, 'get').mockImplementation(async (path: string) => {
      if (path.startsWith('/api/v1/admin/food-options')) {
        return { categories: [], regions: [], dataQualities: ['SOURCED'], servingUnits: ['g'] };
      }
      return {
        items: [{
          id: '1', code: 'ADM-1', name: XSS, category: { code: 'C', name: '<b>Danh mục</b>' },
          servingDescription: '1 tô', kcalPerServing: 400, dataQuality: 'SOURCED', active: true, revision: 1,
        }],
        page: 0, size: 20, totalItems: 1, totalPages: 1, hasNext: false,
      };
    });
    const { container } = render(
      <MemoryRouter>
        <FoodsPage />
      </MemoryRouter>,
    );
    await waitFor(() => expect(screen.getByText(XSS)).toBeTruthy());
    expect(screen.getByText('<b>Danh mục</b>')).toBeTruthy();
    expect(container.querySelector('tbody img')).toBeNull();
    expect(container.querySelector('tbody b')).toBeNull();
    expect((window as unknown as { __xss?: number }).__xss).toBeUndefined();
  });
});
