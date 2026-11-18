import { useEffect, useMemo, useState, type FormEvent } from 'react';
import { api, ApiError, describeError } from '../api/client';
import type { AdminUserItem, UserStatus } from '../api/types';
import { useCurrentUser } from '../auth/AuthContext';
import { Alert, Field, Modal, Pagination, StatusBadge, getInitials } from '../components/common';
import { IconLock, IconSearch, IconShield, IconUnlock, IconUsers } from '../components/icons';
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
    setNotice(
      user.status === 'LOCKED'
        ? `Đã khóa ${user.email}. Mọi phiên đăng nhập của tài khoản này đã bị thu hồi.`
        : `Đã mở khóa ${user.email}. Người dùng cần đăng nhập lại.`,
    );
    void reload();
  };

  const hasFilters = Boolean(keyword.trim() || status);

  return (
    <section className="page-section">
      <div className="page-header">
        <div className="page-header-title">
          <div className="title-row">
            <span className="page-icon page-icon-sky">
              <IconUsers size={20} />
            </span>
            <div>
              <h1>Tài khoản Người dùng</h1>
              <p className="page-subtitle">
                Giám sát danh sách người dùng, vai trò hệ thống và thu hồi phiên đăng nhập tức thì khi cần khóa tài
                khoản.
              </p>
            </div>
          </div>
        </div>
        <div className="page-header-actions">
          {data && <span className="count-pill">{data.totalItems.toLocaleString('vi-VN')} tài khoản</span>}
        </div>
      </div>

      <Alert kind="success">{notice}</Alert>

      <div className="toolbar-card">
        <div className="filters">
          <div className="search-field">
            <IconSearch size={16} className="search-icon" />
            <input
              type="search"
              placeholder="Tìm theo địa chỉ email hoặc họ tên…"
              value={keyword}
              maxLength={100}
              onChange={(e) => setKeyword(e.target.value)}
            />
          </div>
          <select value={status} onChange={(e) => setStatus(e.target.value)} aria-label="Trạng thái">
            <option value="">Mọi trạng thái</option>
            <option value="ACTIVE">Hoạt động</option>
            <option value="LOCKED">Đã khóa</option>
          </select>
          {hasFilters && (
            <button
              type="button"
              className="btn-ghost"
              onClick={() => {
                setKeyword('');
                setStatus('');
              }}
            >
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
              <th>Tài khoản</th>
              <th>Họ và tên</th>
              <th>Vai trò</th>
              <th>Ngày tham gia</th>
              <th>Trạng thái</th>
              <th className="action-col">Thao tác</th>
            </tr>
          </thead>
          <tbody>
            {data?.items.map((u) => {
              // Backend vẫn chặn; ở đây chỉ để không mời bấm nút chắc chắn bị từ chối.
              const locked = u.status === 'LOCKED';
              const manageable = u.role === 'USER' && u.id !== me?.id;
              return (
                <tr key={u.id}>
                  <td>
                    <div className="user-cell">
                      <span className={`avatar-sm${u.role === 'ADMIN' ? ' avatar-admin' : ''}`}>
                        {getInitials(u.fullName)}
                      </span>
                      <span className="cell-title">{u.email}</span>
                    </div>
                  </td>
                  <td>{u.fullName}</td>
                  <td>
                    {u.role === 'ADMIN' ? (
                      <span className="tag tag-admin">
                        <IconShield size={12} /> Quản trị
                      </span>
                    ) : (
                      <span className="tag tag-neutral">Người dùng</span>
                    )}
                  </td>
                  <td>{new Date(u.createdAt).toLocaleDateString('vi-VN')}</td>
                  <td>
                    <StatusBadge active={!locked} on="Hoạt động" off="Đã khóa" offDanger />
                  </td>
                  <td className="action-col">
                    {manageable ? (
                      <button
                        type="button"
                        className={locked ? 'btn-row-edit' : 'danger btn-row-lock'}
                        onClick={() => {
                          setNotice(null);
                          setTarget(u);
                        }}
                      >
                        {locked ? <IconUnlock size={14} /> : <IconLock size={14} />}
                        <span>{locked ? 'Mở khóa' : 'Khóa'}</span>
                      </button>
                    ) : (
                      <span className="muted small">{u.id === me?.id ? 'Tài khoản của bạn' : 'Được bảo vệ'}</span>
                    )}
                  </td>
                </tr>
              );
            })}
            {data && data.items.length === 0 && (
              <tr>
                <td colSpan={6} className="empty-cell">
                  Không có tài khoản nào phù hợp với bộ lọc hiện tại.
                </td>
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

function StatusDialog({
  user,
  onDone,
  onClose,
}: {
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
    <Modal
      title={next === 'LOCKED' ? 'Xác nhận khóa tài khoản' : 'Mở khóa tài khoản'}
      size="md"
      onClose={onClose}
    >
      <form onSubmit={submit} className="form" noValidate>
        <div className="dialog-target-box">
          <span className="avatar-sm">{getInitials(user.fullName)}</span>
          <div>
            <div className="cell-title">{user.fullName}</div>
            <div className="muted small">{user.email}</div>
          </div>
        </div>

        <p className="muted" style={{ margin: 0 }}>
          {next === 'LOCKED'
            ? 'Người dùng sẽ bị đăng xuất khỏi mọi thiết bị ngay ở thao tác kế tiếp và không thể đăng nhập cho tới khi được mở khóa.'
            : 'Mở khóa không tự khôi phục các phiên cũ đã thu hồi; người dùng cần đăng nhập lại bằng mật khẩu.'}
        </p>

        <Alert kind="error">{error}</Alert>

        <Field
          label={next === 'LOCKED' ? 'Lý do khóa tài khoản *' : 'Ghi chú mở khóa (tùy chọn)'}
          error={fieldError}
          hint="Nội dung này được ghi nhận vào nhật ký kiểm toán (audit_logs)"
        >
          <textarea
            rows={3}
            placeholder={next === 'LOCKED' ? 'Nhập lý do khóa (ví dụ: Vi phạm điều khoản sử dụng)…' : 'Ghi chú thêm…'}
            maxLength={300}
            value={reason}
            onChange={(e) => setReason(e.target.value)}
          />
        </Field>

        <div className="form-actions">
          <button type="button" onClick={onClose} disabled={busy}>
            Hủy
          </button>
          <button
            type="submit"
            className={next === 'LOCKED' ? 'danger' : 'primary'}
            disabled={busy || (next === 'LOCKED' && !reason.trim())}
          >
            {busy ? 'Đang xử lý…' : next === 'LOCKED' ? 'Khóa tài khoản' : 'Xác nhận mở khóa'}
          </button>
        </div>
      </form>
    </Modal>
  );
}
