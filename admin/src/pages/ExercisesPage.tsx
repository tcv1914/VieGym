import { useEffect, useMemo, useState } from 'react';
import { api, describeError } from '../api/client';
import type { AdminExerciseDetail, AdminExerciseItem, ExerciseFilters } from '../api/types';
import { Alert, Modal, Pagination, StatusBadge } from '../components/common';
import { useDebounced, usePagedList } from '../components/usePagedList';
import { ExerciseForm } from './ExerciseForm';

export function ExercisesPage() {
  const [keyword, setKeyword] = useState('');
  const [muscleGroup, setMuscleGroup] = useState('');
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

  const label = (list: { code: string; name: string }[] | undefined, code: string) =>
    list?.find((o) => o.code === code)?.name ?? code;

  const saved = (exercise: AdminExerciseDetail, created: boolean) => {
    setEditing(undefined);
    setNotice(`${created ? 'Đã thêm' : 'Đã lưu'} bài “${exercise.name}”.`);
    void reload();
  };

  return (
    <section>
      <div className="page-header">
        <h1>Bài tập</h1>
        <button type="button" className="primary" disabled={!filters} onClick={() => { setNotice(null); setEditing(null); }}>
          + Thêm bài
        </button>
      </div>
      <Alert kind="success">{notice}</Alert>
      <Alert kind="error">{filtersError}</Alert>

      <div className="filters">
        <input
          type="search"
          placeholder="Tìm theo tên (không dấu) hoặc mã"
          value={keyword}
          maxLength={100}
          onChange={(e) => setKeyword(e.target.value)}
        />
        <select value={muscleGroup} onChange={(e) => setMuscleGroup(e.target.value)} aria-label="Nhóm cơ">
          <option value="">Mọi nhóm cơ</option>
          {filters?.muscleGroups.map((o) => <option key={o.code} value={o.code}>{o.name}</option>)}
        </select>
        <select value={active} onChange={(e) => setActive(e.target.value)} aria-label="Trạng thái">
          <option value="">Mọi trạng thái</option>
          <option value="true">Đang hiển thị</option>
          <option value="false">Đã ẩn</option>
        </select>
      </div>

      <Alert kind="error">{error}</Alert>
      <div className={`table-wrap${loading ? ' is-loading' : ''}`}>
        <table>
          <thead>
            <tr>
              <th />
              <th>Tên bài</th>
              <th>Nhóm cơ</th>
              <th>Thiết bị</th>
              <th>Độ khó</th>
              <th>Trạng thái</th>
              <th />
            </tr>
          </thead>
          <tbody>
            {data?.items.map((x) => (
              <tr key={x.id}>
                <td className="thumb-cell">
                  {x.thumbnailPreviewUrl ? <img className="thumb-sm" src={x.thumbnailPreviewUrl} alt="" /> : <span className="thumb-sm placeholder" />}
                </td>
                <td>
                  {x.name}
                  <div className="muted small">{x.code}</div>
                </td>
                <td>{label(filters?.muscleGroups, x.muscleGroup)}</td>
                <td>{label(filters?.equipment, x.equipment)}</td>
                <td>{label(filters?.difficulties, x.difficulty)}</td>
                <td><StatusBadge active={x.active} /></td>
                <td>
                  <button type="button" disabled={!filters} onClick={() => { setNotice(null); setEditing(x.id); }}>
                    Sửa
                  </button>
                </td>
              </tr>
            ))}
            {data && data.items.length === 0 && (
              <tr>
                <td colSpan={7} className="muted center">Không có bài nào phù hợp.</td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
      <Pagination page={data} onPage={setPage} />

      {editing !== undefined && filters && (
        <Modal title={editing ? 'Sửa bài tập' : 'Thêm bài tập'} onClose={() => setEditing(undefined)}>
          <ExerciseForm id={editing} filters={filters} onSaved={saved} onCancel={() => setEditing(undefined)} />
        </Modal>
      )}
    </section>
  );
}
