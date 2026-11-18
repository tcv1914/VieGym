import { useState, type FormEvent } from 'react';
import { Navigate, useLocation, useNavigate } from 'react-router-dom';
import { api, ApiError, describeError } from '../api/client';
import { useCurrentUser } from '../auth/AuthContext';
import { safeRedirectPath } from '../auth/redirect';
import { Alert, Field } from '../components/common';
import { IconBowl, IconDumbbell, IconEye, IconEyeOff, IconShield, IconUsers } from '../components/icons';

export function LoginPage() {
  const user = useCurrentUser();
  const navigate = useNavigate();
  const location = useLocation();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [fieldErrors, setFieldErrors] = useState<Record<string, string>>({});

  const rawFrom = (location.state as { from?: unknown } | null)?.from;
  const from = rawFrom === undefined || rawFrom === '/' ? '/dashboard' : safeRedirectPath(rawFrom, '/dashboard');
  if (user) return <Navigate to={from} replace />;

  const submit = async (e: FormEvent) => {
    e.preventDefault();
    setBusy(true);
    setError(null);
    setFieldErrors({});
    try {
      await api.login(email.trim(), password);
      navigate(from, { replace: true });
    } catch (err) {
      if (err instanceof ApiError && err.code === 'VALIDATION_ERROR') setFieldErrors(err.fieldErrors);
      else if (err instanceof ApiError && err.code === 'INVALID_CREDENTIALS') setError('Email hoặc mật khẩu không đúng');
      else setError(describeError(err));
    } finally {
      setBusy(false);
    }
  };

  return (
    <div className="login-page">
      <div className="login-shell">
        <div className="login-showcase">
          <div className="showcase-brand">
            <div className="brand-emblem brand-emblem-lg">
              <IconDumbbell size={26} />
            </div>
            <div>
              <div className="showcase-title">VieGym</div>
              <div className="showcase-badge">ADMINISTRATION</div>
            </div>
          </div>

          <div className="showcase-copy">
            <h1>Hệ thống Quản trị Tập luyện &amp; Dinh dưỡng Việt</h1>
            <p>
              Nền tảng điều hành tập trung cho danh mục bài tập thể hình, cơ sở dữ liệu dinh dưỡng món ăn Việt Nam và
              kiểm soát an toàn tài khoản người dùng.
            </p>
          </div>

          <ul className="showcase-features">
            <li>
              <span className="feature-icon">
                <IconDumbbell size={18} />
              </span>
              <div>
                <strong>Thư viện 1.300+ bài tập chuẩn hóa</strong>
                <span>Quản lý nhóm cơ, thiết bị, hướng dẫn kỹ thuật và GIF minh họa trực quan.</span>
              </div>
            </li>
            <li>
              <span className="feature-icon">
                <IconBowl size={18} />
              </span>
              <div>
                <strong>Kho dinh dưỡng ẩm thực Việt</strong>
                <span>Đối chiếu công thức năng lượng Atwater (4P + 4C + 9F) và bảo toàn lịch sử thực đơn.</span>
              </div>
            </li>
            <li>
              <span className="feature-icon">
                <IconUsers size={18} />
              </span>
              <div>
                <strong>Phân quyền &amp; thu hồi phiên tức thì</strong>
                <span>Chỉ cho phép tài khoản ADMIN; khóa tài khoản tự động thu hồi toàn bộ refresh token.</span>
              </div>
            </li>
          </ul>
        </div>

        <form className="card login-card" onSubmit={submit} noValidate>
          <div className="login-card-header">
            <span className="login-chip">
              <IconShield size={14} /> Cổng Quản trị viên
            </span>
            <h2>Đăng nhập VieGym Admin</h2>
            <p className="muted">Chỉ dành cho tài khoản có vai trò quản trị (ADMIN).</p>
          </div>

          <Alert kind="error">{error}</Alert>

          <Field label="Email quản trị" error={fieldErrors.email}>
            <input
              type="email"
              placeholder="admin@viegym.vn"
              autoComplete="username"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              required
            />
          </Field>

          <Field label="Mật khẩu" error={fieldErrors.password}>
            <div className="password-wrap">
              <input
                type={showPassword ? 'text' : 'password'}
                placeholder="Nhập mật khẩu của bạn"
                autoComplete="current-password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                required
              />
              <button
                type="button"
                className="password-toggle"
                aria-label={showPassword ? 'Ẩn mật khẩu' : 'Hiện mật khẩu'}
                onClick={() => setShowPassword((s) => !s)}
              >
                {showPassword ? <IconEyeOff size={17} /> : <IconEye size={17} />}
              </button>
            </div>
          </Field>

          <button type="submit" className="primary btn-lg" disabled={busy || !email || !password}>
            {busy ? 'Đang xác thực…' : 'Đăng nhập hệ thống'}
          </button>

          <p className="login-security-note">
            Phiên đăng nhập được lưu trên bộ nhớ trình duyệt (không lưu token vào localStorage) nhằm đảm bảo an toàn
            bảo mật.
          </p>
        </form>
      </div>
    </div>
  );
}
