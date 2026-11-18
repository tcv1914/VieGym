import { NavLink, Outlet, useLocation, useNavigate } from 'react-router-dom';
import { api } from '../api/client';
import { useCurrentUser } from '../auth/AuthContext';
import { getInitials } from './common';
import { IconBowl, IconDashboard, IconDumbbell, IconLogOut, IconShield, IconUsers } from './icons';

const NAV_ITEMS = [
  { to: '/dashboard', label: 'Tổng quan', desc: 'Thống kê hệ thống', icon: IconDashboard },
  { to: '/exercises', label: 'Bài tập', desc: 'Thư viện & Media', icon: IconDumbbell },
  { to: '/foods', label: 'Món ăn Việt', desc: 'Dinh dưỡng & Khẩu phần', icon: IconBowl },
  { to: '/users', label: 'Tài khoản', desc: 'Người dùng & Phiên', icon: IconUsers },
];

function pageBreadcrumb(pathname: string): string {
  if (pathname.startsWith('/dashboard')) return 'Bảng điều khiển tổng quan';
  if (pathname.startsWith('/exercises')) return 'Quản lý thư viện bài tập';
  if (pathname.startsWith('/foods')) return 'Quản lý dinh dưỡng món Việt';
  if (pathname.startsWith('/users')) return 'Quản lý tài khoản & phân quyền';
  return 'Hệ thống quản trị';
}

export function Layout() {
  const user = useCurrentUser();
  const navigate = useNavigate();
  const location = useLocation();

  const logout = async () => {
    await api.logout();
    navigate('/login', { replace: true });
  };

  const today = new Date().toLocaleDateString('vi-VN', {
    weekday: 'long',
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
  });

  return (
    <div className="shell">
      <aside className="sidebar">
        <div className="sidebar-brand">
          <div className="brand-emblem">
            <IconDumbbell size={22} />
          </div>
          <div className="brand-copy">
            <span className="brand-title">VieGym</span>
            <span className="brand-pill">ADMIN PORTAL</span>
          </div>
        </div>

        <div className="sidebar-section-label">ĐIỀU HƯỚNG QUẢN TRỊ</div>
        <nav className="sidebar-nav" aria-label="Điều hướng chính">
          {NAV_ITEMS.map(({ to, label, desc, icon: Icon }) => (
            <NavLink key={to} to={to} className={({ isActive }) => `nav-item${isActive ? ' active' : ''}`}>
              <span className="nav-icon">
                <Icon size={18} />
              </span>
              <span className="nav-text">
                <span className="nav-label">{label}</span>
                <span className="nav-desc">{desc}</span>
              </span>
            </NavLink>
          ))}
        </nav>

        <div className="sidebar-footer">
          <div className="admin-profile">
            <div className="avatar-badge">{getInitials(user?.fullName)}</div>
            <div className="admin-meta">
              <div className="admin-name" title={user?.fullName}>
                {user?.fullName || 'Quản trị viên'}
              </div>
              <div className="admin-email" title={user?.email}>
                {user?.email}
              </div>
            </div>
          </div>
          <div className="sidebar-footer-actions">
            <span className="role-chip">
              <IconShield size={13} /> ADMIN
            </span>
            <button type="button" className="btn-logout" onClick={logout}>
              <IconLogOut size={15} />
              <span>Đăng xuất</span>
            </button>
          </div>
        </div>
      </aside>

      <div className="workspace">
        <header className="workspace-topbar">
          <div className="workspace-crumb">
            <span className="crumb-root">VieGym Admin</span>
            <span className="crumb-sep">/</span>
            <span className="crumb-current">{pageBreadcrumb(location.pathname)}</span>
          </div>
          <div className="workspace-date">{today}</div>
        </header>

        <main className="content">
          <Outlet />
        </main>
      </div>
    </div>
  );
}
