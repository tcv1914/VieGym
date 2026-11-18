import { useCallback, useEffect, useState, type FormEvent } from 'react';
import { api, ApiError, describeError } from '../api/client';
import {
  DATA_QUALITY_LABELS,
  type AdminFoodDetail,
  type DataQuality,
  type FoodOptions,
  type FoodRequest,
} from '../api/types';
import { Alert, Field, blankToNull, parseNumber } from '../components/common';

interface FormState {
  name: string;
  nameEn: string;
  categoryCode: string;
  region: string;
  servingDescription: string;
  servingSize: string;
  servingUnit: string;
  kcalPerServing: string;
  proteinPerServing: string;
  carbsPerServing: string;
  fatPerServing: string;
  dataQuality: DataQuality;
  source: string;
  sourceUrl: string;
  imageUrl: string;
  reviewNote: string;
  active: boolean;
}

const EMPTY: FormState = {
  name: '',
  nameEn: '',
  categoryCode: '',
  region: '',
  servingDescription: '',
  servingSize: '',
  servingUnit: '',
  kcalPerServing: '',
  proteinPerServing: '',
  carbsPerServing: '',
  fatPerServing: '',
  dataQuality: 'SOURCED',
  source: '',
  sourceUrl: '',
  imageUrl: '',
  reviewNote: '',
  active: true,
};

const NUMBER_FIELDS = [
  'servingSize',
  'kcalPerServing',
  'proteinPerServing',
  'carbsPerServing',
  'fatPerServing',
] as const;

function fromDetail(d: AdminFoodDetail): FormState {
  const s = (n: number | null) => (n === null ? '' : String(n));
  return {
    name: d.name,
    nameEn: d.nameEn ?? '',
    categoryCode: d.category.code,
    region: d.region?.code ?? '',
    servingDescription: d.servingDescription,
    servingSize: s(d.servingSize),
    servingUnit: d.servingUnit ?? '',
    kcalPerServing: s(d.kcalPerServing),
    proteinPerServing: s(d.proteinPerServing),
    carbsPerServing: s(d.carbsPerServing),
    fatPerServing: s(d.fatPerServing),
    dataQuality: d.dataQuality,
    source: d.source,
    sourceUrl: d.sourceUrl ?? '',
    imageUrl: d.imageUrl ?? '',
    reviewNote: d.reviewNote ?? '',
    active: d.active,
  };
}

/** 4P + 4C + 9F; chỉ để admin tự đối chiếu, backend mới là nơi chặn (docs/20 §4). */
function atwater(f: FormState): number | null {
  const p = parseNumber(f.proteinPerServing);
  const c = parseNumber(f.carbsPerServing);
  const fat = parseNumber(f.fatPerServing);
  if (p === null || c === null || fat === null || [p, c, fat].some(Number.isNaN)) return null;
  return 4 * p + 4 * c + 9 * fat;
}

export function FoodForm({
  id,
  options,
  onSaved,
  onCancel,
}: {
  id: string | null;
  options: FoodOptions;
  onSaved: (food: AdminFoodDetail, created: boolean) => void;
  onCancel: () => void;
}) {
  const [form, setForm] = useState<FormState>(EMPTY);
  const [detail, setDetail] = useState<AdminFoodDetail | null>(null);
  const [loading, setLoading] = useState(id !== null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [conflict, setConflict] = useState(false);
  const [fieldErrors, setFieldErrors] = useState<Record<string, string>>({});

  const load = useCallback(async () => {
    if (!id) return;
    setLoading(true);
    setError(null);
    setConflict(false);
    setFieldErrors({});
    try {
      const d = await api.get<AdminFoodDetail>(`/api/v1/admin/foods/${id}`);
      setDetail(d);
      setForm(fromDetail(d));
    } catch (e) {
      setError(describeError(e));
    } finally {
      setLoading(false);
    }
  }, [id]);

  useEffect(() => {
    void load();
  }, [load]);

  const set = <K extends keyof FormState>(key: K, value: FormState[K]) => setForm((f) => ({ ...f, [key]: value }));

  const submit = async (e: FormEvent) => {
    e.preventDefault();
    const localErrors: Record<string, string> = {};
    for (const key of NUMBER_FIELDS) {
      if (Number.isNaN(parseNumber(form[key]))) localErrors[key] = 'Không phải số hợp lệ';
    }
    if (Object.keys(localErrors).length > 0) {
      setFieldErrors(localErrors);
      return;
    }
    const body: FoodRequest = {
      name: form.name.trim(),
      nameEn: blankToNull(form.nameEn),
      categoryCode: form.categoryCode,
      region: blankToNull(form.region),
      servingDescription: form.servingDescription.trim(),
      servingSize: parseNumber(form.servingSize),
      servingUnit: blankToNull(form.servingUnit),
      kcalPerServing: parseNumber(form.kcalPerServing),
      proteinPerServing: parseNumber(form.proteinPerServing),
      carbsPerServing: parseNumber(form.carbsPerServing),
      fatPerServing: parseNumber(form.fatPerServing),
      dataQuality: form.dataQuality,
      source: form.source.trim(),
      sourceUrl: blankToNull(form.sourceUrl),
      imageUrl: blankToNull(form.imageUrl),
      reviewNote: blankToNull(form.reviewNote),
      active: form.active,
      ...(detail ? { revision: detail.revision } : {}),
    };
    setBusy(true);
    setError(null);
    setConflict(false);
    setFieldErrors({});
    try {
      const saved = detail
        ? await api.put<AdminFoodDetail>(`/api/v1/admin/foods/${detail.id}`, body)
        : await api.post<AdminFoodDetail>('/api/v1/admin/foods', body);
      onSaved(saved, !detail);
    } catch (err) {
      if (err instanceof ApiError && err.code === 'VERSION_CONFLICT') setConflict(true);
      else if (err instanceof ApiError && Object.keys(err.fieldErrors).length > 0) {
        setFieldErrors(err.fieldErrors);
        setError('Vui lòng sửa các trường được đánh dấu.');
      } else setError(describeError(err));
    } finally {
      setBusy(false);
    }
  };

  if (loading) return <p className="muted">Đang tải thông tin món ăn…</p>;
  if (id && !detail) return <Alert kind="error">{error ?? 'Không tải được món ăn'}</Alert>;

  const estimated = atwater(form);
  const kcal = parseNumber(form.kcalPerServing);
  const diffPct =
    estimated !== null && kcal !== null && !Number.isNaN(kcal) && kcal > 0
      ? Math.round((Math.abs(kcal - estimated) / kcal) * 100)
      : null;
  const atwaterOk = diffPct === null || diffPct <= 15;
  const fe = fieldErrors;
  const previewImg = /^https?:\/\/\S+$/i.test(form.imageUrl.trim()) ? form.imageUrl.trim() : null;

  return (
    <form onSubmit={submit} noValidate className="form">
      {detail && (
        <div className="meta-banner">
          <span>
            Mã định danh: <code>{detail.code}</code>
          </span>
          <span>·</span>
          <span>Phiên bản (revision): <strong>#{detail.revision}</strong></span>
        </div>
      )}
      {conflict && (
        <div className="alert alert-error" role="alert">
          <div className="alert-body">
            Món này đã được sửa ở nơi khác sau khi bạn mở. Tải lại để xem bản mới (thay đổi chưa lưu sẽ mất).{' '}
            <button type="button" onClick={load}>
              Tải lại
            </button>
          </div>
        </div>
      )}
      <Alert kind="error">{error}</Alert>

      <div className="grid-2">
        <Field label="Tên món *" error={fe.name}>
          <input
            placeholder="Ví dụ: Phở bò tái nạm"
            value={form.name}
            maxLength={150}
            onChange={(e) => set('name', e.target.value)}
          />
        </Field>
        <Field label="Tên tiếng Anh" error={fe.nameEn}>
          <input
            placeholder="Ví dụ: Beef Noodle Soup"
            value={form.nameEn}
            maxLength={200}
            onChange={(e) => set('nameEn', e.target.value)}
          />
        </Field>
        <Field label="Danh mục *" error={fe.categoryCode}>
          <select value={form.categoryCode} onChange={(e) => set('categoryCode', e.target.value)}>
            <option value="">— Chọn danh mục —</option>
            {options.categories.map((c) => (
              <option key={c.code} value={c.code}>
                {c.name}
              </option>
            ))}
          </select>
        </Field>
        <Field label="Vùng miền" error={fe.region}>
          <select value={form.region} onChange={(e) => set('region', e.target.value)}>
            <option value="">— Không phân vùng —</option>
            {options.regions.map((r) => (
              <option key={r.code} value={r.code}>
                {r.name}
              </option>
            ))}
          </select>
        </Field>
      </div>

      <fieldset>
        <legend>Khẩu phần chuẩn &amp; Thành phần dinh dưỡng</legend>
        <div className="grid-3">
          <Field label="Nhãn khẩu phần *" error={fe.servingDescription} hint="Ví dụ: 1 tô vừa, 1 đĩa, 100g">
            <input
              value={form.servingDescription}
              maxLength={100}
              onChange={(e) => set('servingDescription', e.target.value)}
            />
          </Field>
          <Field label="Khối lượng" error={fe.servingSize} hint="Bỏ trống nếu nguồn không ghi">
            <input inputMode="decimal" value={form.servingSize} onChange={(e) => set('servingSize', e.target.value)} />
          </Field>
          <Field label="Đơn vị" error={fe.servingUnit}>
            <select value={form.servingUnit} onChange={(e) => set('servingUnit', e.target.value)}>
              <option value="">—</option>
              {options.servingUnits.map((u) => (
                <option key={u} value={u}>
                  {u}
                </option>
              ))}
            </select>
          </Field>
        </div>
        <div className="grid-4">
          <Field label="Năng lượng (kcal) *" error={fe.kcalPerServing}>
            <input
              inputMode="decimal"
              value={form.kcalPerServing}
              onChange={(e) => set('kcalPerServing', e.target.value)}
            />
          </Field>
          <Field label="Đạm / Protein (g) *" error={fe.proteinPerServing}>
            <input
              inputMode="decimal"
              value={form.proteinPerServing}
              onChange={(e) => set('proteinPerServing', e.target.value)}
            />
          </Field>
          <Field label="Bột đường / Carbs (g) *" error={fe.carbsPerServing}>
            <input
              inputMode="decimal"
              value={form.carbsPerServing}
              onChange={(e) => set('carbsPerServing', e.target.value)}
            />
          </Field>
          <Field label="Chất béo / Fat (g) *" error={fe.fatPerServing}>
            <input
              inputMode="decimal"
              value={form.fatPerServing}
              onChange={(e) => set('fatPerServing', e.target.value)}
            />
          </Field>
        </div>
        {estimated !== null && kcal !== null && !Number.isNaN(kcal) && (
          <div className={`atwater-box ${atwaterOk ? 'atwater-ok' : 'atwater-warn'}`}>
            <span>
              Đối chiếu Atwater (4×Đạm + 4×Bột đường + 9×Béo):{' '}
              <strong>{estimated.toLocaleString('vi-VN', { maximumFractionDigits: 1 })} kcal</strong>
            </span>
            {diffPct !== null && (
              <span className="atwater-badge">
                Độ lệch {diffPct}% {atwaterOk ? '· Đạt ngưỡng ≤ 15%' : '· Vượt ngưỡng 15% (không thể bật hiển thị)'}
              </span>
            )}
          </div>
        )}
      </fieldset>

      <fieldset>
        <legend>Nguồn dữ liệu &amp; Hình ảnh</legend>
        <div className="grid-2">
          <Field label="Mức tin cậy *" error={fe.dataQuality}>
            <select value={form.dataQuality} onChange={(e) => set('dataQuality', e.target.value as DataQuality)}>
              {options.dataQualities.map((q) => (
                <option key={q} value={q}>
                  {DATA_QUALITY_LABELS[q]}
                </option>
              ))}
            </select>
          </Field>
          <Field label="Nguồn số liệu *" error={fe.source}>
            <input
              placeholder="Ví dụ: Bảng thành phần thực phẩm Việt Nam - Viện Dinh Dưỡng"
              value={form.source}
              maxLength={200}
              onChange={(e) => set('source', e.target.value)}
            />
          </Field>
          <Field label="URL nguồn tham khảo" error={fe.sourceUrl}>
            <input
              type="url"
              placeholder="https://..."
              value={form.sourceUrl}
              maxLength={500}
              onChange={(e) => set('sourceUrl', e.target.value)}
            />
          </Field>
          <div className="media-row">
            <Field label="URL ảnh minh họa" error={fe.imageUrl}>
              <input
                type="url"
                placeholder="https://..."
                value={form.imageUrl}
                maxLength={500}
                onChange={(e) => set('imageUrl', e.target.value)}
              />
            </Field>
            {previewImg && <img className="thumb" src={previewImg} alt="" />}
          </div>
        </div>
        <Field label="Ghi chú rà soát nội bộ" error={fe.reviewNote} hint="Lý do ẩn hoặc chờ rà soát; người dùng không nhìn thấy">
          <textarea
            rows={2}
            value={form.reviewNote}
            maxLength={300}
            onChange={(e) => set('reviewNote', e.target.value)}
          />
        </Field>
      </fieldset>

      <label className="checkbox-card">
        <input type="checkbox" checked={form.active} onChange={(e) => set('active', e.target.checked)} />
        <div>
          <strong>Hiển thị món ăn trong ứng dụng người dùng</strong>
          <span className="muted small">
            Bỏ chọn để ẩn khỏi danh sách tìm kiếm; các bữa ăn lịch sử đã lưu snapshot dinh dưỡng vẫn giữ nguyên.
          </span>
        </div>
      </label>

      <div className="form-actions">
        <button type="button" onClick={onCancel} disabled={busy}>
          Hủy
        </button>
        <button type="submit" className="primary" disabled={busy || conflict}>
          {busy ? 'Đang lưu…' : detail ? 'Lưu thay đổi' : 'Thêm món ăn'}
        </button>
      </div>
    </form>
  );
}
