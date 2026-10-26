/// Địa chỉ backend, truyền khi chạy: --dart-define=API_BASE_URL=http://127.0.0.1:8080
const apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://127.0.0.1:8080',
);

const apiTimeout = Duration(seconds: 10);
