import { useEffect, useMemo, useState } from 'react';
import { api, describeError } from '../api/client';
import { DATA_QUALITY_LABELS, type AdminFoodDetail, type AdminFoodItem, type FoodOptions } from '../api/types';
import { Alert, Modal, Pagination, StatusBadge, formatNumber } from '../components/common';
import { useDebounced, usePagedList } from '../components/usePagedList';
import { FoodForm } from './FoodForm';

export function FoodsPage() {
  const [keyword, setKeyword] = useState('');
  const [category, setCategory] = useState('');
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

  const saved = (food: AdminFoodDetail, created: boolean) => {
    setEditing(undefined);
    setNotice(`${created ? 'Đã thêm' : 'Đã lưu'} món “${food.name}”.`);
    void reload();
  };

  return (
    <section>
      <div className="page-header">
        <h1>Món ăn</h1>
        <button type="button" className="primary" disabled={!options} onClick={() => { setNotice(null); setEditing(null); }}>
          + Thêm món
        </button>
      </div>
      <Alert kind="success">{notice}</Alert>
      <Alert kind="error">{optionsError}</Alert>

      <div className="filters">
        <input
          type="search"
          placeholder="Tìm theo tên (không dấu) hoặc mã"
          value={keyword}
          maxLength={100}
          onChange={(e) => setKeyword(e.target.value)}
        />
        <select value={category} onChange={(e) => setCategory(e.target.value)} aria-label="Danh mục">
          <option value="">Mọi danh mục</option>
          {options?.categories.map((c) => (
            <option key={c.code} value={c.code}>{c.name}</option>
          ))}
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
              <th>Tên món</th>
              <th>Danh mục</th>
              <th>Khẩu phần</th>
              <th className="num">kcal</th>
              <th>Tin cậy</th>
              <th>Trạng thái</th>
              <th />
            </tr>
          </thead>
          <tbody>
            {data?.items.map((f) => (
              <tr key={f.id}>
                <td>
                  {f.name}
                  <div className="muted small">{f.code}</div>
                </td>
                <td>{f.category.name}</td>
                <td>{f.servingDescription}</td>
                <td className="num">{formatNumber(f.kcalPerServing)}</td>
                <td>{DATA_QUALITY_LABELS[f.dataQuality]}</td>
                <td><StatusBadge active={f.active} /></td>
                <td>
                  <button type="button" disabled={!options} onClick={() => { setNotice(null); setEditing(f.id); }}>
                    Sửa
                  </button>
                </td>
              </tr>
            ))}
            {data && data.items.length === 0 && (
              <tr>
                <td colSpan={7} className="muted center">Không có món nào phù hợp.</td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
      <Pagination page={data} onPage={setPage} />

      {editing !== undefined && options && (
        <Modal title={editing ? 'Sửa món ăn' : 'Thêm món ăn'} onClose={() => setEditing(undefined)}>
          <FoodForm id={editing} options={options} onSaved={saved} onCancel={() => setEditing(undefined)} />
        </Modal>
      )}
    </section>
  );
}
