import { NavLink, Outlet, useNavigate } from 'react-router-dom';
import { api } from '../api/client';
import { useCurrentUser } from '../auth/AuthContext';

export function Layout() {
  const user = useCurrentUser();
  const navigate = useNavigate();
  const logout = async () => {
    await api.logout();
    navigate('/login', { replace: true });
  };
  return (
    <div className="shell">
      <header className="topbar">
        <span className="brand">VieGym Admin</span>
        <nav>
          <NavLink to="/foods">Món ăn</NavLink>
          <NavLink to="/exercises">Bài tập</NavLink>
          <NavLink to="/users">Tài khoản</NavLink>
        </nav>
        <div className="topbar-user">
          <span title={user?.email}>{user?.fullName}</span>
          <button type="button" onClick={logout}>
            Đăng xuất
          </button>
        </div>
      </header>
      <main className="content">
        <Outlet />
      </main>
    </div>
  );
}
