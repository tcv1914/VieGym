import { useEffect, useMemo, useState } from 'react';
import { useSearchParams } from 'react-router-dom';
import { api, describeError } from '../api/client';
import type { AdminExerciseDetail, AdminExerciseItem, Difficulty, ExerciseFilters } from '../api/types';
import { Alert, Modal, Pagination, StatusBadge } from '../components/common';
import { IconDumbbell, IconEdit, IconPlus, IconSearch } from '../components/icons';
import { useDebounced, usePagedList } from '../components/usePagedList';
import { ExerciseForm } from './ExerciseForm';

function difficultyClass(d: Difficulty): string {
  if (d === 'BEGINNER') return 'tag-diff-beginner';
  if (d === 'INTERMEDIATE') return 'tag-diff-intermediate';
  return 'tag-diff-advanced';
}

export function ExercisesPage() {
  const [searchParams, setSearchParams] = useSearchParams();
  const [keyword, setKeyword] = useState('');
  const [muscleGroup, setMuscleGroup] = useState(() => searchParams.get('muscleGroup') ?? '');
  const [active, setActive] = useState('');
  const [page, setPage] = useState(0);
  const [filters, setFilters] = useState<ExerciseFilters | null>(null);
  const [filtersError, setFiltersError] = useState<string | null>(null);
  const [editing, setEditing] = useState<string | null | undefined>(undefined);
  const [notice, setNotice] = useState<string | null>(null);
  const debouncedKeyword = useDebounced(keyword);

  const query = useMemo(() => {
    const q = new URLSearchParams();
    if (debouncedKeyword.trim()) q.set('keyword', debouncedKeyword.trim());
    if (muscleGroup) q.set('muscleGroup', muscleGroup);
    if (active) q.set('active', active);
    return q;
  }, [debouncedKeyword, muscleGroup, active]);

  useEffect(() => setPage(0), [query]);
  const { data, loading, error, reload } = usePagedList<AdminExerciseItem>('/api/v1/admin/exercises', query, page);

  useEffect(() => {
    // Nhãn tiếng Việt lấy từ backend, không giữ bộ danh mục thứ hai ở frontend.
    api.get<ExerciseFilters>('/api/v1/exercise-filters').then(setFilters, (e) => setFiltersError(describeError(e)));
  }, []);

  useEffect(() => {
    if (filters && searchParams.get('new') === '1') {
      setEditing(null);
      const next = new URLSearchParams(searchParams);
      next.delete('new');
      setSearchParams(next, { replace: true });
    }
  }, [filters, searchParams, setSearchParams]);

  const label = (list: { code: string; name: string }[] | undefined, code: string) =>
    list?.find((o) => o.code === code)?.name ?? code;

  const saved = (exercise: AdminExerciseDetail, created: boolean) => {
    setEditing(undefined);
    setNotice(`${created ? 'Đã thêm' : 'Đã lưu'} bài “${exercise.name}”.`);
    void reload();
  };

  const hasFilters = Boolean(keyword.trim() || muscleGroup || active);
  const resetFilters = () => {
    setKeyword('');
    setMuscleGroup('');
    setActive('');
    if (searchParams.has('muscleGroup')) {
      const next = new URLSearchParams(searchParams);
      next.delete('muscleGroup');
      setSearchParams(next, { replace: true });
    }
  };

  return (
    <section className="page-section">
      <div className="page-header">
        <div className="page-header-title">
          <div className="title-row">
            <span className="page-icon page-icon-emerald">
              <IconDumbbell size={20} />
            </span>
            <div>
              <h1>Thư viện Bài tập</h1>
              <p className="page-subtitle">
                Quản lý danh mục bài tập thể hình, phân nhóm cơ, hướng dẫn kỹ thuật và hình động GIF minh họa.
              </p>
            </div>
          </div>
        </div>
        <div className="page-header-actions">
          {data && <span className="count-pill">{data.totalItems.toLocaleString('vi-VN')} bài tập</span>}
          <button
            type="button"
            className="primary"
            disabled={!filters}
            onClick={() => {
              setNotice(null);
              setEditing(null);
            }}
          >
            <IconPlus size={16} />
            <span>Thêm bài</span>
          </button>
        </div>
      </div>

      <Alert kind="success">{notice}</Alert>
      <Alert kind="error">{filtersError}</Alert>

      <div className="toolbar-card">
        <div className="filters">
          <div className="search-field">
            <IconSearch size={16} className="search-icon" />
            <input
              type="search"
              placeholder="Tìm theo tên bài tập (có dấu / không dấu) hoặc mã…"
              value={keyword}
              maxLength={100}
              onChange={(e) => setKeyword(e.target.value)}
            />
          </div>
          <select value={muscleGroup} onChange={(e) => setMuscleGroup(e.target.value)} aria-label="Nhóm cơ">
            <option value="">Mọi nhóm cơ</option>
            {filters?.muscleGroups.map((o) => (
              <option key={o.code} value={o.code}>
                {o.name}
              </option>
            ))}
          </select>
          <select value={active} onChange={(e) => setActive(e.target.value)} aria-label="Trạng thái">
            <option value="">Mọi trạng thái</option>
            <option value="true">Đang hiển thị</option>
            <option value="false">Đã ẩn</option>
          </select>
          {hasFilters && (
            <button type="button" className="btn-ghost" onClick={resetFilters}>
              Xóa lọc
            </button>
          )}
        </div>
      </div>

      <Alert kind="error">{error}</Alert>

      <div className={`table-wrap${loading ? ' is-loading' : ''}`}>
        <table>
          <thead>
            <tr>
              <th className="thumb-cell">Ảnh</th>
              <th>Tên bài tập</th>
              <th>Nhóm cơ</th>
              <th>Thiết bị</th>
              <th>Độ khó</th>
              <th>Trạng thái</th>
              <th className="action-col">Thao tác</th>
            </tr>
          </thead>
          <tbody>
            {data?.items.map((x) => (
              <tr key={x.id}>
                <td className="thumb-cell">
                  {x.thumbnailPreviewUrl ? (
                    <img className="thumb-sm" src={x.thumbnailPreviewUrl} alt="" loading="lazy" />
                  ) : (
                    <span className="thumb-sm placeholder">
                      <IconDumbbell size={16} />
                    </span>
                  )}
                </td>
                <td>
                  <div className="cell-title">{x.name}</div>
                  <div className="code-sub">{x.code}</div>
                </td>
                <td>
                  <span className="tag tag-muscle">{label(filters?.muscleGroups, x.muscleGroup)}</span>
                </td>
                <td>
                  <span className="tag tag-neutral">{label(filters?.equipment, x.equipment)}</span>
                </td>
                <td>
                  <span className={`tag ${difficultyClass(x.difficulty)}`}>
                    {label(filters?.difficulties, x.difficulty)}
                  </span>
                </td>
                <td>
                  <StatusBadge active={x.active} />
                </td>
                <td className="action-col">
                  <button
                    type="button"
                    className="btn-row-edit"
                    disabled={!filters}
                    onClick={() => {
                      setNotice(null);
                      setEditing(x.id);
                    }}
                  >
                    <IconEdit size={14} />
                    <span>Sửa</span>
                  </button>
                </td>
              </tr>
            ))}
            {data && data.items.length === 0 && (
              <tr>
                <td colSpan={7} className="empty-cell">
                  Không có bài tập nào phù hợp với bộ lọc hiện tại.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
      <Pagination page={data} onPage={setPage} />

      {editing !== undefined && filters && (
        <Modal
          title={editing ? 'Chỉnh sửa bài tập' : 'Thêm bài tập mới'}
          subtitle="Cập nhật phân loại nhóm cơ, hướng dẫn từng bước và ảnh/GIF minh họa."
          onClose={() => setEditing(undefined)}
        >
          <ExerciseForm id={editing} filters={filters} onSaved={saved} onCancel={() => setEditing(undefined)} />
        </Modal>
      )}
    </section>
  );
}
