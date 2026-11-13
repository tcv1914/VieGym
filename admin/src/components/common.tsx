import { useEffect, useRef, type ReactNode } from 'react';
import type { Page } from '../api/types';

export function Pagination<T>({ page, onPage }: { page: Page<T> | null; onPage: (p: number) => void }) {
  if (!page) return null;
  return (
    <div className="pagination">
      <button type="button" disabled={page.page === 0} onClick={() => onPage(page.page - 1)}>
        ‹ Trước
      </button>
      <span>
        Trang {page.totalPages === 0 ? 0 : page.page + 1}/{page.totalPages} · {page.totalItems} bản ghi
      </span>
      <button type="button" disabled={!page.hasNext} onClick={() => onPage(page.page + 1)}>
        Sau ›
      </button>
    </div>
  );
}

export function Alert({ kind, children }: { kind: 'error' | 'success' | 'info'; children: ReactNode }) {
  if (!children) return null;
  return (
    <div className={`alert alert-${kind}`} role={kind === 'error' ? 'alert' : 'status'}>
      {children}
    </div>
  );
}

export function StatusBadge({ active, on = 'Hiển thị', off = 'Đã ẩn' }: { active: boolean; on?: string; off?: string }) {
  return <span className={`badge ${active ? 'badge-on' : 'badge-off'}`}>{active ? on : off}</span>;
}

/** Ô nhập kèm nhãn và lỗi theo trường từ backend (fieldErrors). */
export function Field({ label, error, children, hint }: { label: string; error?: string; hint?: string; children: ReactNode }) {
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
export function Modal({ title, children, onClose }: { title: string; children: ReactNode; onClose: () => void }) {
  const ref = useRef<HTMLDivElement>(null);
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => e.key === 'Escape' && onClose();
    document.addEventListener('keydown', onKey);
    ref.current?.querySelector<HTMLElement>('input, textarea, select, button')?.focus();
    return () => document.removeEventListener('keydown', onKey);
  }, [onClose]);
  return (
    <div className="modal-backdrop" onMouseDown={(e) => e.target === e.currentTarget && onClose()}>
      <div className="modal" role="dialog" aria-modal="true" aria-label={title} ref={ref}>
        <div className="modal-header">
          <h2>{title}</h2>
          <button type="button" className="icon-button" aria-label="Đóng" onClick={onClose}>
            ×
          </button>
        </div>
        {children}
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
