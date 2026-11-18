import { useCallback, useEffect, useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { api, describeError } from '../api/client';
import {
  DATA_QUALITY_LABELS,
  type AdminExerciseItem,
  type AdminFoodItem,
  type AdminUserItem,
  type DataQuality,
  type ExerciseFilters,
  type FoodOptions,
  type Page,
} from '../api/types';
import { useCurrentUser } from '../auth/AuthContext';
import { Alert, StatusBadge, getInitials } from '../components/common';
import {
  IconActivity,
  IconBowl,
  IconDumbbell,
  IconPlus,
  IconRefresh,
  IconShield,
  IconUsers,
} from '../components/icons';

interface SystemHealth {
  status: string;
  service: string;
  database: string;
  message?: string;
}

interface BreakdownItem {
  code: string;
  name: string;
  count: number;
}

interface DashboardStats {
  totalUsers: number;
  activeUsers: number;
  lockedUsers: number;
  recentUsers: AdminUserItem[];

  totalExercises: number;
  activeExercises: number;
  hiddenExercises: number;
  sampleExercises: AdminExerciseItem[];
  exerciseFilters: ExerciseFilters;
  muscleBreakdown: BreakdownItem[];

  totalFoods: number;
  activeFoods: number;
  hiddenFoods: number;
  categoryBreakdown: BreakdownItem[];
  qualityBreakdown: Record<DataQuality, number>;
  avgKcal: number;

  health: SystemHealth | null;
}

const DONUT_COLORS = ['#16a34a', '#0ea5e9', '#f59e0b', '#8b5cf6', '#ec4899', '#14b8a6', '#64748b'];

export function DashboardPage() {
  const user = useCurrentUser();
  const navigate = useNavigate();
  const [stats, setStats] = useState<DashboardStats | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const [
        usersPage,
        activeUsersPage,
        lockedUsersPage,
        exPage,
        activeExPage,
        hiddenExPage,
        exFilters,
        foodsPage,
        activeFoodsPage,
        hiddenFoodsPage,
        foodOptions,
        health,
      ] = await Promise.all([
        api.get<Page<AdminUserItem>>('/api/v1/admin/users?page=0&size=6'),
        api.get<Page<AdminUserItem>>('/api/v1/admin/users?status=ACTIVE&page=0&size=1'),
        api.get<Page<AdminUserItem>>('/api/v1/admin/users?status=LOCKED&page=0&size=1'),
        api.get<Page<AdminExerciseItem>>('/api/v1/admin/exercises?page=0&size=6'),
        api.get<Page<AdminExerciseItem>>('/api/v1/admin/exercises?active=true&page=0&size=1'),
        api.get<Page<AdminExerciseItem>>('/api/v1/admin/exercises?active=false&page=0&size=1'),
        api.get<ExerciseFilters>('/api/v1/exercise-filters'),
        api.get<Page<AdminFoodItem>>('/api/v1/admin/foods?page=0&size=100'),
        api.get<Page<AdminFoodItem>>('/api/v1/admin/foods?active=true&page=0&size=1'),
        api.get<Page<AdminFoodItem>>('/api/v1/admin/foods?active=false&page=0&size=1'),
        api.get<FoodOptions>('/api/v1/admin/food-options'),
        api.get<SystemHealth>('/api/v1/system/health').catch(() => null),
      ]);

      const [muscleCounts, categoryCounts] = await Promise.all([
        Promise.all(
          exFilters.muscleGroups.map(async (mg) => {
            const res = await api.get<Page<AdminExerciseItem>>(
              `/api/v1/admin/exercises?muscleGroup=${encodeURIComponent(mg.code)}&page=0&size=1`,
            );
            return { code: mg.code, name: mg.name, count: res.totalItems };
          }),
        ),
        Promise.all(
          foodOptions.categories.map(async (cat) => {
            const res = await api.get<Page<AdminFoodItem>>(
              `/api/v1/admin/foods?category=${encodeURIComponent(cat.code)}&page=0&size=1`,
            );
            return { code: cat.code, name: cat.name, count: res.totalItems };
          }),
        ),
      ]);

      const qualityBreakdown: Record<DataQuality, number> = { SOURCED: 0, ESTIMATED: 0, DEMO: 0 };
      let kcalSum = 0;
      for (const item of foodsPage.items) {
        qualityBreakdown[item.dataQuality] = (qualityBreakdown[item.dataQuality] ?? 0) + 1;
        kcalSum += item.kcalPerServing;
      }
      const avgKcal = foodsPage.items.length > 0 ? Math.round(kcalSum / foodsPage.items.length) : 0;

      setStats({
        totalUsers: usersPage.totalItems,
        activeUsers: activeUsersPage.totalItems,
        lockedUsers: lockedUsersPage.totalItems,
        recentUsers: usersPage.items,

        totalExercises: exPage.totalItems,
        activeExercises: activeExPage.totalItems,
        hiddenExercises: hiddenExPage.totalItems,
        sampleExercises: exPage.items,
        exerciseFilters: exFilters,
        muscleBreakdown: [...muscleCounts].sort((a, b) => b.count - a.count),

        totalFoods: foodsPage.totalItems,
        activeFoods: activeFoodsPage.totalItems,
        hiddenFoods: hiddenFoodsPage.totalItems,
        categoryBreakdown: [...categoryCounts].sort((a, b) => b.count - a.count),
        qualityBreakdown,
        avgKcal,

        health,
      });
    } catch (e) {
      setError(describeError(e));
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    void load();
  }, [load]);

  const totalCatalog = (stats?.totalExercises ?? 0) + (stats?.totalFoods ?? 0);
  const activeCatalog = (stats?.activeExercises ?? 0) + (stats?.activeFoods ?? 0);
  const visibilityPct = totalCatalog > 0 ? Math.round((activeCatalog / totalCatalog) * 100) : 100;
  const exActivePct = stats && stats.totalExercises > 0
    ? Math.round((stats.activeExercises / stats.totalExercises) * 100)
    : 0;
  const foodActivePct = stats && stats.totalFoods > 0
    ? Math.round((stats.activeFoods / stats.totalFoods) * 100)
    : 0;
  const userActivePct = stats && stats.totalUsers > 0
    ? Math.round((stats.activeUsers / stats.totalUsers) * 100)
    : 0;

  const maxMuscle = Math.max(1, ...(stats?.muscleBreakdown.map((m) => m.count) ?? [1]));

  const labelFrom = (list: { code: string; name: string }[] | undefined, code: string) =>
    list?.find((o) => o.code === code)?.name ?? code;

  return (
    <section className="dashboard-section">
      <div className="dash-hero">
        <div className="dash-hero-copy">
          <div className="dash-hero-badges">
            <span className="hero-eyebrow">TRUNG TÂM ĐIỀU HÀNH VIEGYM</span>
            {stats?.health?.status === 'UP' && (
              <span className="health-pill">
                <span className="health-dot" />
                API &amp; PostgreSQL: Trực tuyến
              </span>
            )}
          </div>
          <h1>Xin chào, {user?.fullName || 'Quản trị viên'}!</h1>
          <p>
            Theo dõi tổng quan kho dữ liệu tập luyện, dinh dưỡng món Việt và trạng thái tài khoản người dùng theo thời
            gian thực.
          </p>
        </div>

        <div className="dash-hero-actions">
          <button type="button" className="btn-hero-ghost" onClick={load} disabled={loading}>
            <IconRefresh size={16} />
            <span>{loading ? 'Đang tải…' : 'Làm mới'}</span>
          </button>
          <button type="button" className="btn-hero-lime" onClick={() => navigate('/exercises?new=1')}>
            <IconPlus size={16} />
            <span>Thêm bài tập</span>
          </button>
          <button type="button" className="btn-hero-white" onClick={() => navigate('/foods?new=1')}>
            <IconPlus size={16} />
            <span>Thêm món ăn</span>
          </button>
        </div>
      </div>

      <Alert kind="error">{error}</Alert>

      <div className={`kpi-grid${loading && !stats ? ' is-loading' : ''}`}>
        <Link to="/exercises" className="kpi-card kpi-emerald">
          <div className="kpi-top">
            <span className="kpi-label">Thư viện Bài tập</span>
            <span className="kpi-icon kpi-icon-emerald">
              <IconDumbbell size={20} />
            </span>
          </div>
          <div className="kpi-value">{stats ? stats.totalExercises.toLocaleString('vi-VN') : '—'}</div>
          <div className="kpi-sub">
            <span className="text-ok">{stats?.activeExercises.toLocaleString('vi-VN') ?? 0} hiển thị</span>
            <span>·</span>
            <span>{stats?.hiddenExercises.toLocaleString('vi-VN') ?? 0} đã ẩn</span>
          </div>
          <div className="kpi-progress">
            <div className="kpi-progress-bar bg-emerald" style={{ width: `${exActivePct}%` }} />
          </div>
        </Link>

        <Link to="/foods" className="kpi-card kpi-amber">
          <div className="kpi-top">
            <span className="kpi-label">Kho Món ăn Việt</span>
            <span className="kpi-icon kpi-icon-amber">
              <IconBowl size={20} />
            </span>
          </div>
          <div className="kpi-value">{stats ? stats.totalFoods.toLocaleString('vi-VN') : '—'}</div>
          <div className="kpi-sub">
            <span className="text-ok">{stats?.activeFoods.toLocaleString('vi-VN') ?? 0} hiển thị</span>
            <span>·</span>
            <span>TB {stats?.avgKcal ?? 0} kcal/khẩu phần</span>
          </div>
          <div className="kpi-progress">
            <div className="kpi-progress-bar bg-amber" style={{ width: `${foodActivePct}%` }} />
          </div>
        </Link>

        <Link to="/users" className="kpi-card kpi-sky">
          <div className="kpi-top">
            <span className="kpi-label">Tài khoản Hệ thống</span>
            <span className="kpi-icon kpi-icon-sky">
              <IconUsers size={20} />
            </span>
          </div>
          <div className="kpi-value">{stats ? stats.totalUsers.toLocaleString('vi-VN') : '—'}</div>
          <div className="kpi-sub">
            <span className="text-ok">{stats?.activeUsers.toLocaleString('vi-VN') ?? 0} hoạt động</span>
            <span>·</span>
            <span className={stats && stats.lockedUsers > 0 ? 'text-danger' : ''}>
              {stats?.lockedUsers.toLocaleString('vi-VN') ?? 0} đã khóa
            </span>
          </div>
          <div className="kpi-progress">
            <div className="kpi-progress-bar bg-sky" style={{ width: `${userActivePct}%` }} />
          </div>
        </Link>

        <div className="kpi-card kpi-violet">
          <div className="kpi-top">
            <span className="kpi-label">Độ phủ Danh mục</span>
            <span className="kpi-icon kpi-icon-violet">
              <IconActivity size={20} />
            </span>
          </div>
          <div className="kpi-value">{stats ? `${visibilityPct}%` : '—'}</div>
          <div className="kpi-sub">
            <span>{stats?.muscleBreakdown.length ?? 0} nhóm cơ</span>
            <span>·</span>
            <span>{stats?.categoryBreakdown.length ?? 0} nhóm món Việt</span>
          </div>
          <div className="kpi-progress">
            <div className="kpi-progress-bar bg-violet" style={{ width: `${visibilityPct}%` }} />
          </div>
        </div>
      </div>

      {stats && (
        <>
          <div className="analytics-grid">
            <div className="panel">
              <div className="panel-header">
                <div>
                  <h2>Phân bố Bài tập theo Nhóm cơ</h2>
                  <p className="panel-subtitle">Nhấn vào từng nhóm cơ để lọc nhanh trong thư viện bài tập</p>
                </div>
                <Link to="/exercises" className="panel-link">
                  Xem toàn bộ →
                </Link>
              </div>

              <div className="bar-chart">
                {stats.muscleBreakdown.map((item) => {
                  const pctOfMax = Math.max(4, Math.round((item.count / maxMuscle) * 100));
                  const share = stats.totalExercises > 0
                    ? ((item.count / stats.totalExercises) * 100).toFixed(1)
                    : '0.0';
                  return (
                    <button
                      key={item.code}
                      type="button"
                      className="bar-row"
                      onClick={() => navigate(`/exercises?muscleGroup=${encodeURIComponent(item.code)}`)}
                    >
                      <span className="bar-label">{item.name}</span>
                      <span className="bar-track">
                        <span className="bar-fill" style={{ width: `${pctOfMax}%` }} />
                      </span>
                      <span className="bar-metrics">
                        <strong>{item.count.toLocaleString('vi-VN')}</strong>
                        <span className="muted small">({share}%)</span>
                      </span>
                    </button>
                  );
                })}
              </div>
            </div>

            <div className="panel">
              <div className="panel-header">
                <div>
                  <h2>Cơ cấu Món ăn Việt</h2>
                  <p className="panel-subtitle">Tỷ trọng danh mục ẩm thực và độ tin cậy nguồn dinh dưỡng</p>
                </div>
                <Link to="/foods" className="panel-link">
                  Quản lý món →
                </Link>
              </div>

              <FoodDonutChart items={stats.categoryBreakdown} total={stats.totalFoods} onSelect={(code) => navigate(`/foods?category=${encodeURIComponent(code)}`)} />

              <div className="quality-strip">
                <div className="quality-strip-title">Độ tin cậy số liệu (mẫu kiểm tra):</div>
                <div className="quality-pills">
                  {(['SOURCED', 'ESTIMATED', 'DEMO'] as DataQuality[]).map((q) => (
                    <span key={q} className={`tag tag-quality-${q.toLowerCase()}`}>
                      {DATA_QUALITY_LABELS[q]}: <strong>{stats.qualityBreakdown[q] ?? 0}</strong>
                    </span>
                  ))}
                </div>
              </div>
            </div>
          </div>

          <div className="bottom-grid">
            <div className="panel">
              <div className="panel-header">
                <div>
                  <h2>Tài khoản mới nhất</h2>
                  <p className="panel-subtitle">Các tài khoản đăng ký gần đây trên hệ thống</p>
                </div>
                <Link to="/users" className="panel-link">
                  Quản lý tài khoản →
                </Link>
              </div>

              <div className="mini-list">
                {stats.recentUsers.map((u) => (
                  <div key={u.id} className="mini-row">
                    <div className="user-cell">
                      <span className={`avatar-sm${u.role === 'ADMIN' ? ' avatar-admin' : ''}`}>
                        {getInitials(u.fullName)}
                      </span>
                      <div>
                        <div className="cell-title">{u.fullName}</div>
                        <div className="muted small">{u.email}</div>
                      </div>
                    </div>
                    <div className="mini-row-right">
                      {u.role === 'ADMIN' ? (
                        <span className="tag tag-admin">
                          <IconShield size={12} /> Quản trị
                        </span>
                      ) : (
                        <span className="tag tag-neutral">Người dùng</span>
                      )}
                      <StatusBadge active={u.status === 'ACTIVE'} on="Hoạt động" off="Đã khóa" offDanger />
                    </div>
                  </div>
                ))}
                {stats.recentUsers.length === 0 && <p className="muted center">Chưa có tài khoản nào.</p>}
              </div>
            </div>

            <div className="panel">
              <div className="panel-header">
                <div>
                  <h2>Thư viện Bài tập tiêu biểu</h2>
                  <p className="panel-subtitle">Xem nhanh trạng thái media và phân loại kỹ thuật</p>
                </div>
                <Link to="/exercises" className="panel-link">
                  Mở thư viện →
                </Link>
              </div>

              <div className="mini-list">
                {stats.sampleExercises.map((ex) => (
                  <div key={ex.id} className="mini-row">
                    <div className="user-cell">
                      {ex.thumbnailPreviewUrl ? (
                        <img className="thumb-sm" src={ex.thumbnailPreviewUrl} alt="" />
                      ) : (
                        <span className="thumb-sm placeholder">
                          <IconDumbbell size={16} />
                        </span>
                      )}
                      <div>
                        <div className="cell-title">{ex.name}</div>
                        <div className="muted small">
                          {labelFrom(stats.exerciseFilters.muscleGroups, ex.muscleGroup)} ·{' '}
                          {labelFrom(stats.exerciseFilters.difficulties, ex.difficulty)}
                        </div>
                      </div>
                    </div>
                    <StatusBadge active={ex.active} />
                  </div>
                ))}
                {stats.sampleExercises.length === 0 && <p className="muted center">Chưa có bài tập nào.</p>}
              </div>
            </div>
          </div>
        </>
      )}
    </section>
  );
}

function FoodDonutChart({
  items,
  total,
  onSelect,
}: {
  items: BreakdownItem[];
  total: number;
  onSelect: (code: string) => void;
}) {
  const nonZero = items.filter((i) => i.count > 0);
  const top = nonZero.slice(0, 6);
  const restCount = nonZero.slice(6).reduce((acc, x) => acc + x.count, 0);
  const segments = restCount > 0 ? [...top, { code: '', name: 'Danh mục khác', count: restCount }] : top;
  const sum = Math.max(1, segments.reduce((acc, x) => acc + x.count, 0));

  const radius = 54;
  const circumference = 2 * Math.PI * radius;
  let offset = 0;

  return (
    <div className="donut-layout">
      <div className="donut-figure">
        <svg width="148" height="148" viewBox="0 0 148 148" aria-hidden="true">
          <circle cx="74" cy="74" r={radius} fill="none" stroke="#edf2ef" strokeWidth="18" />
          {segments.map((seg, idx) => {
            const len = (seg.count / sum) * circumference;
            const dashOffset = -offset;
            offset += len;
            return (
              <circle
                key={seg.code || 'other'}
                cx="74"
                cy="74"
                r={radius}
                fill="none"
                stroke={DONUT_COLORS[idx % DONUT_COLORS.length]}
                strokeWidth="18"
                strokeDasharray={`${len} ${circumference - len}`}
                strokeDashoffset={dashOffset}
                transform="rotate(-90 74 74)"
              />
            );
          })}
        </svg>
        <div className="donut-center">
          <strong>{total.toLocaleString('vi-VN')}</strong>
          <span>món Việt</span>
        </div>
      </div>

      <div className="donut-legend">
        {segments.map((seg, idx) => {
          const pct = total > 0 ? Math.round((seg.count / total) * 100) : 0;
          const color = DONUT_COLORS[idx % DONUT_COLORS.length];
          return seg.code ? (
            <button key={seg.code} type="button" className="legend-row" onClick={() => onSelect(seg.code)}>
              <span className="legend-dot" style={{ background: color }} />
              <span className="legend-name">{seg.name}</span>
              <span className="legend-val">
                {seg.count} <span className="muted">({pct}%)</span>
              </span>
            </button>
          ) : (
            <div key="other" className="legend-row legend-row-static">
              <span className="legend-dot" style={{ background: color }} />
              <span className="legend-name">{seg.name}</span>
              <span className="legend-val">
                {seg.count} <span className="muted">({pct}%)</span>
              </span>
            </div>
          );
        })}
        {segments.length === 0 && <p className="muted small">Chưa có dữ liệu phân loại món ăn.</p>}
      </div>
    </div>
  );
}
