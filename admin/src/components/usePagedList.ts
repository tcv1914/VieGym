import { useCallback, useEffect, useRef, useState } from 'react';
import { api, describeError } from '../api/client';
import type { Page } from '../api/types';

/**
 * Tải một trang danh sách theo query; bỏ kết quả của request cũ nếu query đã đổi (gõ tìm nhanh).
 * {@code query} là chuỗi tham số không gồm page/size.
 */
export function usePagedList<T>(basePath: string, query: URLSearchParams, page: number, size = 20) {
  const [data, setData] = useState<Page<T> | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const seq = useRef(0);
  const queryString = query.toString();

  const reload = useCallback(async () => {
    const mine = ++seq.current;
    setLoading(true);
    setError(null);
    const params = new URLSearchParams(queryString);
    params.set('page', String(page));
    params.set('size', String(size));
    try {
      const result = await api.get<Page<T>>(`${basePath}?${params}`);
      if (mine === seq.current) setData(result);
    } catch (e) {
      if (mine === seq.current) setError(describeError(e));
    } finally {
      if (mine === seq.current) setLoading(false);
    }
  }, [basePath, queryString, page, size]);

  useEffect(() => {
    void reload();
  }, [reload]);

  return { data, loading, error, reload };
}

/** Trì hoãn giá trị khi gõ tìm kiếm. */
export function useDebounced<T>(value: T, delay = 300): T {
  const [debounced, setDebounced] = useState(value);
  useEffect(() => {
    const id = setTimeout(() => setDebounced(value), delay);
    return () => clearTimeout(id);
  }, [value, delay]);
  return debounced;
}
