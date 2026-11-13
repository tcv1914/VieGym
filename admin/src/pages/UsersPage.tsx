import { useEffect, useMemo, useState, type FormEvent } from 'react';
import { api, ApiError, describeError } from '../api/client';
import type { AdminUserItem, UserStatus } from '../api/types';
import { useCurrentUser } from '../auth/AuthContext';
import { Alert, Field, Modal, Pagination, StatusBadge } from '../components/common';
import { useDebounced, usePagedList } from '../components/usePagedList';

export function UsersPage() {
  const me = useCurrentUser();
  const [keyword, setKeyword] = useState('');
  const [status, setStatus] = useState('');
  const [page, setPage] = useState(0);
  const [target, setTarget] = useState<AdminUserItem | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const debouncedKeyword = useDebounced(keyword);

  const query = useMemo(() => {
    const q = new URLSearchParams();
    if (debouncedKeyword.trim()) q.set('keyword', debouncedKeyword.trim());
    if (status) q.set('status', status);
    return q;
  }, [debouncedKeyword, status]);

  useEffect(() => setPage(0), [query]);
  const { data, loading, error, reload } = usePagedList<AdminUserItem>('/api/v1/admin/users', query, page);

  const done = (user: AdminUserItem) => {
    setTarget(null);
    setNotice(user.status === 'LOCKED'
      ? `Đã khóa ${user.email}. Mọi phiên đăng nhập của tài khoản này đã bị thu hồi.`
      : `Đã mở khóa ${user.email}. Người dùng cần đăng nhập lại.`);
    void reload();
  };

  return (
    <section>
      <div className="page-header">
        <h1>Tài khoản</h1>
      </div>
      <Alert kind="success">{notice}</Alert>
      <div className="filters">
        <input
          type="search"
          placeholder="Tìm theo email hoặc họ tên"
          value={keyword}
          maxLength={100}
          onChange={(e) => setKeyword(e.target.value)}
        />
        <select value={status} onChange={(e) => setStatus(e.target.value)} aria-label="Trạng thái">
          <option value="">Mọi trạng thái</option>
          <option value="ACTIVE">Hoạt động</option>
          <option value="LOCKED">Đã khóa</option>
        </select>
      </div>

      <Alert kind="error">{error}</Alert>
      <div className={`table-wrap${loading ? ' is-loading' : ''}`}>
        <table>
          <thead>
            <tr>
              <th>Email</th>
              <th>Họ tên</th>
              <th>Vai trò</th>
              <th>Ngày tạo</th>
              <th>Trạng thái</th>
              <th />
            </tr>
          </thead>
          <tbody>
            {data?.items.map((u) => {
              // Backend vẫn chặn; ở đây chỉ để không mời bấm nút chắc chắn bị từ chối.
              const locked = u.status === 'LOCKED';
              const manageable = u.role === 'USER' && u.id !== me?.id;
              return (
                <tr key={u.id}>
                  <td>{u.email}</td>
                  <td>{u.fullName}</td>
                  <td>{u.role === 'ADMIN' ? 'Quản trị' : 'Người dùng'}</td>
                  <td>{new Date(u.createdAt).toLocaleDateString('vi-VN')}</td>
                  <td><StatusBadge active={!locked} on="Hoạt động" off="Đã khóa" /></td>
                  <td>
                    {manageable ? (
                      <button type="button" className={locked ? '' : 'danger'} onClick={() => { setNotice(null); setTarget(u); }}>
                        {locked ? 'Mở khóa' : 'Khóa'}
                      </button>
                    ) : (
                      <span className="muted small">{u.id === me?.id ? 'Bạn' : '—'}</span>
                    )}
                  </td>
                </tr>
              );
            })}
            {data && data.items.length === 0 && (
              <tr>
                <td colSpan={6} className="muted center">Không có tài khoản nào phù hợp.</td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
      <Pagination page={data} onPage={setPage} />

      {target && <StatusDialog user={target} onDone={done} onClose={() => setTarget(null)} />}
    </section>
  );
}

function StatusDialog({ user, onDone, onClose }: {
  user: AdminUserItem;
  onDone: (u: AdminUserItem) => void;
  onClose: () => void;
}) {
  const next: UserStatus = user.status === 'LOCKED' ? 'ACTIVE' : 'LOCKED';
  const [reason, setReason] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [fieldError, setFieldError] = useState<string | undefined>();

  const submit = async (e: FormEvent) => {
    e.preventDefault();
    setBusy(true);
    setError(null);
    setFieldError(undefined);
    try {
      const saved = await api.put<AdminUserItem>(`/api/v1/admin/users/${user.id}/status`, {
        status: next,
        reason: reason.trim() || null,
      });
      onDone(saved);
    } catch (err) {
      if (err instanceof ApiError && err.fieldErrors.reason) setFieldError(err.fieldErrors.reason);
      else setError(describeError(err));
    } finally {
      setBusy(false);
    }
  };

  return (
    <Modal title={next === 'LOCKED' ? 'Khóa tài khoản' : 'Mở khóa tài khoản'} onClose={onClose}>
      <form onSubmit={submit} className="form" noValidate>
        <p>
          {next === 'LOCKED' ? 'Khóa' : 'Mở khóa'} <strong>{user.email}</strong>?
        </p>
        <p className="muted">
          {next === 'LOCKED'
            ? 'Người dùng bị đăng xuất khỏi mọi thiết bị ngay ở thao tác kế tiếp và không đăng nhập được cho tới khi mở khóa.'
            : 'Mở khóa không khôi phục phiên cũ; người dùng phải đăng nhập lại.'}
        </p>
        <Alert kind="error">{error}</Alert>
        <Field label={next === 'LOCKED' ? 'Lý do khóa *' : 'Ghi chú'} error={fieldError}>
          <textarea rows={3} maxLength={300} value={reason} onChange={(e) => setReason(e.target.value)} />
        </Field>
        <div className="form-actions">
          <button type="button" onClick={onClose} disabled={busy}>
            Hủy
          </button>
          <button type="submit" className={next === 'LOCKED' ? 'danger' : 'primary'}
            disabled={busy || (next === 'LOCKED' && !reason.trim())}>
            {busy ? 'Đang lưu…' : next === 'LOCKED' ? 'Khóa' : 'Mở khóa'}
          </button>
        </div>
      </form>
    </Modal>
  );
}
