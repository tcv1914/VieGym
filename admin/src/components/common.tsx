import { useEffect, useRef, type ReactNode } from 'react';
import type { Page } from '../api/types';
import { IconAlertCircle, IconCheckCircle } from './icons';

export function Pagination<T>({ page, onPage }: { page: Page<T> | null; onPage: (p: number) => void }) {
  if (!page) return null;
  return (
    <div className="pagination">
      <span className="pagination-meta">
        Tổng <strong>{page.totalItems.toLocaleString('vi-VN')}</strong> bản ghi
      </span>
      <div className="pagination-controls">
        <button type="button" className="btn-subtle" disabled={page.page === 0} onClick={() => onPage(page.page - 1)}>
          ‹ Trước
        </button>
        <span className="pagination-page">
          Trang {page.totalPages === 0 ? 0 : page.page + 1} / {page.totalPages}
        </span>
        <button type="button" className="btn-subtle" disabled={!page.hasNext} onClick={() => onPage(page.page + 1)}>
          Sau ›
        </button>
      </div>
    </div>
  );
}

export function Alert({ kind, children }: { kind: 'error' | 'success' | 'info'; children: ReactNode }) {
  if (!children) return null;
  return (
    <div className={`alert alert-${kind}`} role={kind === 'error' ? 'alert' : 'status'}>
      <span className="alert-icon">
        {kind === 'success' ? <IconCheckCircle size={17} /> : <IconAlertCircle size={17} />}
      </span>
      <div className="alert-body">{children}</div>
    </div>
  );
}

export function StatusBadge({
  active,
  on = 'Hiển thị',
  off = 'Đã ẩn',
  offDanger = false,
}: {
  active: boolean;
  on?: string;
  off?: string;
  offDanger?: boolean;
}) {
  const cls = active ? 'badge-on' : offDanger ? 'badge-danger' : 'badge-off';
  return (
    <span className={`badge ${cls}`}>
      <span className="badge-dot" />
      {active ? on : off}
    </span>
  );
}

/** Ô nhập kèm nhãn và lỗi theo trường từ backend (fieldErrors). */
export function Field({
  label,
  error,
  children,
  hint,
}: {
  label: string;
  error?: string;
  hint?: string;
  children: ReactNode;
}) {
  return (
    <label className={`field${error ? ' field-invalid' : ''}`}>
      <span className="field-label">{label}</span>
      {children}
      {hint && !error && <span className="field-hint">{hint}</span>}
      {error && <span className="field-error">{error}</span>}
    </label>
  );
}

/** Hộp thoại tự vẽ (không dùng window.confirm/prompt). */
export function Modal({
  title,
  subtitle,
  size = 'lg',
  children,
  onClose,
}: {
  title: string;
  subtitle?: string;
  size?: 'md' | 'lg';
  children: ReactNode;
  onClose: () => void;
}) {
  const ref = useRef<HTMLDivElement>(null);
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => e.key === 'Escape' && onClose();
    document.addEventListener('keydown', onKey);
    ref.current?.querySelector<HTMLElement>('input, textarea, select, button')?.focus();
    return () => document.removeEventListener('keydown', onKey);
  }, [onClose]);
  return (
    <div className="modal-backdrop" onMouseDown={(e) => e.target === e.currentTarget && onClose()}>
      <div className={`modal modal-${size}`} role="dialog" aria-modal="true" aria-label={title} ref={ref}>
        <div className="modal-header">
          <div>
            <h2>{title}</h2>
            {subtitle && <p className="modal-subtitle">{subtitle}</p>}
          </div>
          <button type="button" className="icon-button" aria-label="Đóng" onClick={onClose}>
            ×
          </button>
        </div>
        <div className="modal-body">{children}</div>
      </div>
    </div>
  );
}

/** Chuỗi rỗng → null; dùng khi gửi các trường không bắt buộc. */
export function blankToNull(value: string): string | null {
  const trimmed = value.trim();
  return trimmed === '' ? null : trimmed;
}

/** "12,5" hoặc "12.5" → 12.5; rỗng → null; sai → NaN (backend sẽ báo lỗi trường). */
export function parseNumber(value: string): number | null {
  const trimmed = value.trim().replace(',', '.');
  if (trimmed === '') return null;
  return Number(trimmed);
}

export function formatNumber(value: number | null | undefined): string {
  if (value === null || value === undefined) return '';
  return value.toLocaleString('vi-VN', { maximumFractionDigits: 2 });
}

export function getInitials(name: string | null | undefined): string {
  if (!name) return 'AD';
  const parts = name.trim().split(/\s+/).filter(Boolean);
  if (parts.length === 0) return 'AD';
  if (parts.length === 1) return parts[0].slice(0, 2).toUpperCase();
  return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
}
