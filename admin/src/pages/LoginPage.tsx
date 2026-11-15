import { useState, type FormEvent } from 'react';
import { Navigate, useLocation, useNavigate } from 'react-router-dom';
import { api, ApiError, describeError } from '../api/client';
import { useCurrentUser } from '../auth/AuthContext';
import { safeRedirectPath } from '../auth/redirect';
import { Alert, Field } from '../components/common';

export function LoginPage() {
  const user = useCurrentUser();
  const navigate = useNavigate();
  const location = useLocation();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [fieldErrors, setFieldErrors] = useState<Record<string, string>>({});

  const from = safeRedirectPath((location.state as { from?: unknown } | null)?.from);
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
      <form className="card login-card" onSubmit={submit} noValidate>
        <h1>VieGym Admin</h1>
        <p className="muted">Chỉ dành cho tài khoản quản trị.</p>
        <Alert kind="error">{error}</Alert>
        <Field label="Email" error={fieldErrors.email}>
          <input type="email" autoComplete="username" value={email} onChange={(e) => setEmail(e.target.value)} required />
        </Field>
        <Field label="Mật khẩu" error={fieldErrors.password}>
          <input
            type="password"
            autoComplete="current-password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            required
          />
        </Field>
        <button type="submit" className="primary" disabled={busy || !email || !password}>
          {busy ? 'Đang đăng nhập…' : 'Đăng nhập'}
        </button>
      </form>
    </div>
  );
}
