import { useCallback, useEffect, useState, type FormEvent } from 'react';
import { api, ApiError, describeError } from '../api/client';
import type {
  AdminExerciseDetail,
  Difficulty,
  Equipment,
  ExerciseFilters,
  ExerciseRequest,
  MediaType,
  MuscleGroup,
} from '../api/types';
import { Alert, Field, blankToNull } from '../components/common';

interface FormState {
  name: string;
  muscleGroup: MuscleGroup | '';
  equipment: Equipment | '';
  difficulty: Difficulty | '';
  instructions: string;
  commonMistakes: string;
  thumbnailUrl: string;
  mediaType: MediaType | '';
  mediaUrl: string;
  contentSource: string;
  mediaLicense: string;
  active: boolean;
}

const EMPTY: FormState = {
  name: '',
  muscleGroup: '',
  equipment: '',
  difficulty: '',
  instructions: '',
  commonMistakes: '',
  thumbnailUrl: '',
  mediaType: '',
  mediaUrl: '',
  contentSource: '',
  mediaLicense: '',
  active: true,
};

const MEDIA_TYPES: { code: MediaType; name: string }[] = [
  { code: 'IMAGE', name: 'Ảnh tĩnh (IMAGE)' },
  { code: 'GIF', name: 'Ảnh động (GIF)' },
  { code: 'VIDEO', name: 'Video (VIDEO)' },
];

const MEDIA_HINT = 'URL http(s) hoặc tệp có sẵn dạng exercises/<tên tệp>; bỏ trống → app dùng ảnh mặc định';

function fromDetail(d: AdminExerciseDetail): FormState {
  return {
    name: d.name,
    muscleGroup: d.muscleGroup,
    equipment: d.equipment,
    difficulty: d.difficulty,
    instructions: d.instructions,
    commonMistakes: d.commonMistakes,
    thumbnailUrl: d.thumbnailUrl ?? '',
    mediaType: d.mediaType ?? '',
    mediaUrl: d.mediaUrl ?? '',
    contentSource: d.contentSource ?? '',
    mediaLicense: d.mediaLicense ?? '',
    active: d.active,
  };
}

export function ExerciseForm({
  id,
  filters,
  onSaved,
  onCancel,
}: {
  id: string | null;
  filters: ExerciseFilters;
  onSaved: (exercise: AdminExerciseDetail, created: boolean) => void;
  onCancel: () => void;
}) {
  const [form, setForm] = useState<FormState>(EMPTY);
  const [detail, setDetail] = useState<AdminExerciseDetail | null>(null);
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
      const d = await api.get<AdminExerciseDetail>(`/api/v1/admin/exercises/${id}`);
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
    const body: ExerciseRequest = {
      name: form.name.trim(),
      muscleGroup: form.muscleGroup,
      equipment: form.equipment,
      difficulty: form.difficulty,
      instructions: form.instructions.trim(),
      commonMistakes: form.commonMistakes.trim(),
      thumbnailUrl: blankToNull(form.thumbnailUrl),
      mediaType: form.mediaType === '' ? null : form.mediaType,
      mediaUrl: blankToNull(form.mediaUrl),
      contentSource: blankToNull(form.contentSource),
      mediaLicense: blankToNull(form.mediaLicense),
      active: form.active,
      ...(detail ? { revision: detail.revision } : {}),
    };
    // Enum rỗng gửi null để backend báo "Vui lòng chọn…" thay vì lỗi parse.
    const payload = Object.fromEntries(Object.entries(body).map(([k, v]) => [k, v === '' ? null : v]));
    setBusy(true);
    setError(null);
    setConflict(false);
    setFieldErrors({});
    try {
      const saved = detail
        ? await api.put<AdminExerciseDetail>(`/api/v1/admin/exercises/${detail.id}`, payload)
        : await api.post<AdminExerciseDetail>('/api/v1/admin/exercises', payload);
      onSaved(saved, !detail);
    } catch (err) {
      if (err instanceof ApiError && err.code === 'VERSION_CONFLICT') setConflict(true);
      else if (err instanceof ApiError && Object.keys(err.fieldErrors).length > 0) {
        setFieldErrors(err.fieldErrors);
        setError(err.code === 'EXERCISE_NAME_TAKEN' ? err.message : 'Vui lòng sửa các trường được đánh dấu.');
      } else setError(describeError(err));
    } finally {
      setBusy(false);
    }
  };

  if (loading) return <p className="muted">Đang tải thông tin bài tập…</p>;
  if (id && !detail) return <Alert kind="error">{error ?? 'Không tải được bài tập'}</Alert>;
  const fe = fieldErrors;

  const showThumbPreview = Boolean(detail?.thumbnailPreviewUrl && form.thumbnailUrl === (detail.thumbnailUrl ?? ''));
  const showMediaPreview = Boolean(
    detail?.mediaPreviewUrl &&
      form.mediaUrl === (detail.mediaUrl ?? '') &&
      (form.mediaType === 'GIF' || form.mediaType === 'IMAGE'),
  );

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
            Bài này đã được sửa ở nơi khác sau khi bạn mở. Tải lại để xem bản mới (thay đổi chưa lưu sẽ mất).{' '}
            <button type="button" onClick={load}>
              Tải lại
            </button>
          </div>
        </div>
      )}
      <Alert kind="error">{error}</Alert>

      <Field label="Tên bài tập *" error={fe.name}>
        <input
          placeholder="Ví dụ: Đẩy ngực ngang với tạ đòn (Barbell Bench Press)"
          value={form.name}
          maxLength={150}
          onChange={(e) => set('name', e.target.value)}
        />
      </Field>

      <div className="grid-3">
        <Field label="Nhóm cơ chính *" error={fe.muscleGroup}>
          <select value={form.muscleGroup} onChange={(e) => set('muscleGroup', e.target.value as MuscleGroup)}>
            <option value="">— Chọn nhóm cơ —</option>
            {filters.muscleGroups.map((o) => (
              <option key={o.code} value={o.code}>
                {o.name}
              </option>
            ))}
          </select>
        </Field>
        <Field label="Thiết bị tập *" error={fe.equipment}>
          <select value={form.equipment} onChange={(e) => set('equipment', e.target.value as Equipment)}>
            <option value="">— Chọn thiết bị —</option>
            {filters.equipment.map((o) => (
              <option key={o.code} value={o.code}>
                {o.name}
              </option>
            ))}
          </select>
        </Field>
        <Field label="Độ khó *" error={fe.difficulty}>
          <select value={form.difficulty} onChange={(e) => set('difficulty', e.target.value as Difficulty)}>
            <option value="">— Chọn độ khó —</option>
            {filters.difficulties.map((o) => (
              <option key={o.code} value={o.code}>
                {o.name}
              </option>
            ))}
          </select>
        </Field>
      </div>

      <Field label="Hướng dẫn kỹ thuật *" error={fe.instructions} hint="Mỗi dòng trình bày một bước thực hiện rõ ràng">
        <textarea
          rows={5}
          maxLength={4000}
          value={form.instructions}
          onChange={(e) => set('instructions', e.target.value)}
        />
      </Field>
      <Field label="Lỗi thường gặp &amp; Lưu ý an toàn *" error={fe.commonMistakes} hint="Mỗi dòng một lưu ý tránh chấn thương">
        <textarea
          rows={3}
          maxLength={4000}
          value={form.commonMistakes}
          onChange={(e) => set('commonMistakes', e.target.value)}
        />
      </Field>

      <fieldset>
        <legend>Hình ảnh &amp; Media minh họa</legend>
        {(showThumbPreview || showMediaPreview) && (
          <div className="media-preview-strip">
            {showThumbPreview && (
              <div className="media-preview-box">
                <img className="thumb" src={detail!.thumbnailPreviewUrl!} alt="" />
                <span className="muted small">Ảnh đại diện hiện tại</span>
              </div>
            )}
            {showMediaPreview && (
              <div className="media-preview-box">
                <img className="thumb" src={detail!.mediaPreviewUrl!} alt="" />
                <span className="muted small">Media động (GIF/Ảnh)</span>
              </div>
            )}
          </div>
        )}
        <Field label="Ảnh đại diện (Thumbnail)" error={fe.thumbnailUrl} hint={MEDIA_HINT}>
          <input value={form.thumbnailUrl} maxLength={500} onChange={(e) => set('thumbnailUrl', e.target.value)} />
        </Field>
        <div className="grid-2">
          <Field label="Loại media" error={fe.mediaType}>
            <select value={form.mediaType} onChange={(e) => set('mediaType', e.target.value as MediaType | '')}>
              <option value="">— Không có —</option>
              {MEDIA_TYPES.map((m) => (
                <option key={m.code} value={m.code}>
                  {m.name}
                </option>
              ))}
            </select>
          </Field>
          <Field label="Đường dẫn media" error={fe.mediaUrl} hint={MEDIA_HINT}>
            <input value={form.mediaUrl} maxLength={500} onChange={(e) => set('mediaUrl', e.target.value)} />
          </Field>
          <Field label="Nguồn nội dung" error={fe.contentSource}>
            <input value={form.contentSource} maxLength={500} onChange={(e) => set('contentSource', e.target.value)} />
          </Field>
          <Field label="Giấy phép bản quyền media" error={fe.mediaLicense}>
            <input value={form.mediaLicense} maxLength={500} onChange={(e) => set('mediaLicense', e.target.value)} />
          </Field>
        </div>
      </fieldset>

      <label className="checkbox-card">
        <input type="checkbox" checked={form.active} onChange={(e) => set('active', e.target.checked)} />
        <div>
          <strong>Hiển thị trong thư viện bài tập</strong>
          <span className="muted small">
            Bỏ chọn để ẩn khỏi danh sách chọn mới; các giáo án và lịch tập đã lưu bài này vẫn hoạt động bình thường.
          </span>
        </div>
      </label>

      <div className="form-actions">
        <button type="button" onClick={onCancel} disabled={busy}>
          Hủy
        </button>
        <button type="submit" className="primary" disabled={busy || conflict}>
          {busy ? 'Đang lưu…' : detail ? 'Lưu thay đổi' : 'Thêm bài tập'}
        </button>
      </div>
    </form>
  );
}
