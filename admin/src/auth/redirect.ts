/**
 * Đích quay lại sau đăng nhập. Chỉ nhận đường dẫn nội bộ dạng "/foods…": chặn "//host", "/\host", URL tuyệt đối
 * và ký tự điều khiển — react-router 6 có lỗi open redirect qua dấu "\" (GHSA-wrjc-x8rr-h8h6), chỉ vá ở v7.
 */
export function safeRedirectPath(from: unknown, fallback = '/foods'): string {
  if (typeof from !== 'string' || !from.startsWith('/')) return fallback;
  if (from.startsWith('//') || from.includes('\\') || /[\u0000-\u001f\u007f]/.test(from)) return fallback;
  return from;
}
