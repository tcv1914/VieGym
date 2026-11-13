/// <reference types="vitest" />
import { defineConfig, loadEnv } from 'vite';
import react from '@vitejs/plugin-react';

// Dev: proxy /api và /media sang backend nên trình duyệt chỉ thấy một origin — không cần mở CORS
// ở backend, không dùng cookie. Backend nghe 127.0.0.1:8080 (docs/31 §5).
export default defineConfig(({ mode }) => {
  const backend = loadEnv(mode, '.', '').VIEGYM_BACKEND_URL || 'http://127.0.0.1:8080';
  return {
    plugins: [react()],
    server: {
      host: '127.0.0.1',
      port: 5173,
      strictPort: true,
      proxy: {
        '/api': { target: backend, changeOrigin: true },
        '/media': { target: backend, changeOrigin: true },
      },
    },
    test: {
      environment: 'jsdom',
      globals: true,
    },
  };
});
