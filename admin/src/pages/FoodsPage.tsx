import { useEffect, useMemo, useState } from 'react';
import { useSearchParams } from 'react-router-dom';
import { api, describeError } from '../api/client';
import { DATA_QUALITY_LABELS, type AdminFoodDetail, type AdminFoodItem, type FoodOptions } from '../api/types';
import { Alert, Modal, Pagination, StatusBadge, formatNumber } from '../components/common';
import { IconBowl, IconEdit, IconPlus, IconSearch } from '../components/icons';
import { useDebounced, usePagedList } from '../components/usePagedList';
import { FoodForm } from './FoodForm';

export function FoodsPage() {
  const [searchParams, setSearchParams] = useSearchParams();
  const [keyword, setKeyword] = useState('');
  const [category, setCategory] = useState(() => searchParams.get('category') ?? '');
  const [active, setActive] = useState('');
  const [page, setPage] = useState(0);
  const [options, setOptions] = useState<FoodOptions | null>(null);
  const [optionsError, setOptionsError] = useState<string | null>(null);
  const [editing, setEditing] = useState<string | null | undefined>(undefined); // undefined = đóng, null = thêm mới
  const [notice, setNotice] = useState<string | null>(null);
  const debouncedKeyword = useDebounced(keyword);

  const query = useMemo(() => {
    const q = new URLSearchParams();
    if (debouncedKeyword.trim()) q.set('keyword', debouncedKeyword.trim());
    if (category) q.set('category', category);
    if (active) q.set('active', active);
    return q;
  }, [debouncedKeyword, category, active]);

  useEffect(() => setPage(0), [query]);
  const { data, loading, error, reload } = usePagedList<AdminFoodItem>('/api/v1/admin/foods', query, page);

  useEffect(() => {
    api.get<FoodOptions>('/api/v1/admin/food-options').then(setOptions, (e) => setOptionsError(describeError(e)));
  }, []);

  useEffect(() => {
    if (options && searchParams.get('new') === '1') {
      setEditing(null);
      const next = new URLSearchParams(searchParams);
      next.delete('new');
      setSearchParams(next, { replace: true });
    }
  }, [options, searchParams, setSearchParams]);

  const saved = (food: AdminFoodDetail, created: boolean) => {
    setEditing(undefined);
    setNotice(`${created ? 'Đã thêm' : 'Đã lưu'} món “${food.name}”.`);
    void reload();
  };

  const hasFilters = Boolean(keyword.trim() || category || active);
  const resetFilters = () => {
    setKeyword('');
    setCategory('');
    setActive('');
    if (searchParams.has('category')) {
      const next = new URLSearchParams(searchParams);
      next.delete('category');
      setSearchParams(next, { replace: true });
    }
  };

  return (
    <section className="page-section">
      <div className="page-header">
        <div className="page-header-title">
          <div className="title-row">
            <span className="page-icon page-icon-amber">
              <IconBowl size={20} />
            </span>
            <div>
              <h1>Món ăn Việt Nam</h1>
              <p className="page-subtitle">
                Quản lý danh mục món ăn, khẩu phần chuẩn và độ tin cậy nguồn dinh dưỡng cho thực đơn người dùng.
              </p>
            </div>
          </div>
        </div>
        <div className="page-header-actions">
          {data && <span className="count-pill">{data.totalItems.toLocaleString('vi-VN')} món</span>}
          <button
            type="button"
            className="primary"
            disabled={!options}
            onClick={() => {
              setNotice(null);
              setEditing(null);
            }}
          >
            <IconPlus size={16} />
            <span>Thêm món</span>
          </button>
        </div>
      </div>

      <Alert kind="success">{notice}</Alert>
      <Alert kind="error">{optionsError}</Alert>

      <div className="toolbar-card">
        <div className="filters">
          <div className="search-field">
            <IconSearch size={16} className="search-icon" />
            <input
              type="search"
              placeholder="Tìm theo tên món (có dấu / không dấu) hoặc mã…"
              value={keyword}
              maxLength={100}
              onChange={(e) => setKeyword(e.target.value)}
            />
          </div>
          <select value={category} onChange={(e) => setCategory(e.target.value)} aria-label="Danh mục">
            <option value="">Mọi danh mục</option>
            {options?.categories.map((c) => (
              <option key={c.code} value={c.code}>
                {c.name}
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
              <th>Tên món</th>
              <th>Danh mục</th>
              <th>Khẩu phần chuẩn</th>
              <th className="num">Năng lượng (kcal)</th>
              <th>Mức tin cậy</th>
              <th>Trạng thái</th>
              <th className="action-col">Thao tác</th>
            </tr>
          </thead>
          <tbody>
            {data?.items.map((f) => (
              <tr key={f.id}>
                <td>
                  <div className="cell-title">{f.name}</div>
                  <div className="code-sub">{f.code}</div>
                </td>
                <td>
                  <span className="tag tag-category">{f.category.name}</span>
                </td>
                <td>{f.servingDescription}</td>
                <td className="num">
                  <span className="kcal-pill">{formatNumber(f.kcalPerServing)}</span>
                </td>
                <td>
                  <span className={`tag tag-quality-${f.dataQuality.toLowerCase()}`}>
                    {DATA_QUALITY_LABELS[f.dataQuality]}
                  </span>
                </td>
                <td>
                  <StatusBadge active={f.active} />
                </td>
                <td className="action-col">
                  <button
                    type="button"
                    className="btn-row-edit"
                    disabled={!options}
                    onClick={() => {
                      setNotice(null);
                      setEditing(f.id);
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
                  Không có món ăn nào phù hợp với bộ lọc hiện tại.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
      <Pagination page={data} onPage={setPage} />

      {editing !== undefined && options && (
        <Modal
          title={editing ? 'Chỉnh sửa món ăn' : 'Thêm món ăn mới'}
          subtitle="Mọi chỉ số dinh dưỡng được tính theo đúng một khẩu phần chuẩn bên dưới."
          onClose={() => setEditing(undefined)}
        >
          <FoodForm id={editing} options={options} onSaved={saved} onCancel={() => setEditing(undefined)} />
        </Modal>
      )}
    </section>
  );
}
