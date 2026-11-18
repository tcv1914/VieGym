import { cleanup, render, screen, waitFor } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { api } from '../api/client';
import { DashboardPage } from '../pages/DashboardPage';

afterEach(() => {
  cleanup();
  vi.restoreAllMocks();
});

describe('DashboardPage — Thống kê tổng quan Admin', () => {
  it('hiển thị KPI tổng hợp, phân bố nhóm cơ, danh mục món ăn và trạng thái hệ thống', async () => {
    vi.spyOn(api, 'get').mockImplementation(async (path: string) => {
      if (path === '/api/v1/system/health') {
        return { status: 'UP', service: 'viegym-backend', database: 'UP' };
      }
      if (path === '/api/v1/exercise-filters') {
        return {
          muscleGroups: [
            { code: 'CHEST', name: 'Ngực' },
            { code: 'LEGS', name: 'Chân' },
          ],
          equipment: [{ code: 'BARBELL', name: 'Tạ đòn' }],
          difficulties: [{ code: 'BEGINNER', name: 'Cơ bản' }],
        };
      }
      if (path === '/api/v1/admin/food-options') {
        return {
          categories: [{ code: 'PHO_BUN', name: 'Phở & Bún' }],
          regions: [],
          dataQualities: ['SOURCED', 'ESTIMATED', 'DEMO'],
          servingUnits: ['g'],
        };
      }
      if (path.startsWith('/api/v1/admin/users?status=ACTIVE')) {
        return { items: [], page: 0, size: 1, totalItems: 14, totalPages: 14, hasNext: true };
      }
      if (path.startsWith('/api/v1/admin/users?status=LOCKED')) {
        return { items: [], page: 0, size: 1, totalItems: 1, totalPages: 1, hasNext: false };
      }
      if (path.startsWith('/api/v1/admin/users')) {
        return {
          items: [
            {
              id: 'u1',
              email: 'admin@viegym.vn',
              fullName: 'Quản trị VieGym',
              role: 'ADMIN',
              status: 'ACTIVE',
              createdAt: '2026-01-10T00:00:00Z',
            },
          ],
          page: 0,
          size: 6,
          totalItems: 15,
          totalPages: 3,
          hasNext: true,
        };
      }
      if (path.startsWith('/api/v1/admin/exercises?muscleGroup=CHEST')) {
        return { items: [], page: 0, size: 1, totalItems: 180, totalPages: 180, hasNext: true };
      }
      if (path.startsWith('/api/v1/admin/exercises?muscleGroup=LEGS')) {
        return { items: [], page: 0, size: 1, totalItems: 320, totalPages: 320, hasNext: true };
      }
      if (path.startsWith('/api/v1/admin/exercises?active=true')) {
        return { items: [], page: 0, size: 1, totalItems: 1324, totalPages: 1324, hasNext: true };
      }
      if (path.startsWith('/api/v1/admin/exercises?active=false')) {
        return { items: [], page: 0, size: 1, totalItems: 3, totalPages: 3, hasNext: true };
      }
      if (path.startsWith('/api/v1/admin/exercises')) {
        return {
          items: [
            {
              id: 'ex1',
              code: 'EX-001',
              name: 'Đẩy ngực ngang',
              muscleGroup: 'CHEST',
              equipment: 'BARBELL',
              difficulty: 'BEGINNER',
              thumbnailPreviewUrl: null,
              active: true,
              revision: 1,
            },
          ],
          page: 0,
          size: 6,
          totalItems: 1327,
          totalPages: 222,
          hasNext: true,
        };
      }
      if (path.startsWith('/api/v1/admin/foods?category=PHO_BUN')) {
        return { items: [], page: 0, size: 1, totalItems: 24, totalPages: 24, hasNext: true };
      }
      if (path.startsWith('/api/v1/admin/foods?active=true')) {
        return { items: [], page: 0, size: 1, totalItems: 58, totalPages: 58, hasNext: true };
      }
      if (path.startsWith('/api/v1/admin/foods?active=false')) {
        return { items: [], page: 0, size: 1, totalItems: 2, totalPages: 2, hasNext: true };
      }
      if (path.startsWith('/api/v1/admin/foods')) {
        return {
          items: [
            {
              id: 'f1',
              code: 'VN-01',
              name: 'Phở bò tái',
              category: { code: 'PHO_BUN', name: 'Phở & Bún' },
              servingDescription: '1 tô',
              kcalPerServing: 420,
              dataQuality: 'SOURCED',
              active: true,
              revision: 1,
            },
          ],
          page: 0,
          size: 100,
          totalItems: 60,
          totalPages: 1,
          hasNext: false,
        };
      }
      throw new Error(`Unexpected path: ${path}`);
    });

    render(
      <MemoryRouter>
        <DashboardPage />
      </MemoryRouter>,
    );

    await waitFor(() => expect(screen.getByText('API & PostgreSQL: Trực tuyến')).toBeTruthy());
    expect(screen.getByText('1.327')).toBeTruthy();
    expect(screen.getByText('Chân')).toBeTruthy();
    expect(screen.getByText('Phở & Bún')).toBeTruthy();
    expect(screen.getByText('Đẩy ngực ngang')).toBeTruthy();
    expect(screen.getByText('admin@viegym.vn')).toBeTruthy();
  });
});
