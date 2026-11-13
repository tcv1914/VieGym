import { createContext, useContext, useEffect, useState, type ReactNode } from 'react';
import { Navigate, useLocation } from 'react-router-dom';
import { api, type SessionUser } from '../api/client';

const AuthContext = createContext<SessionUser | null>(null);

/** Theo dõi phiên của ApiClient: refresh thất bại hoặc bị khóa → user = null → về màn đăng nhập. */
export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<SessionUser | null>(api.user);
  useEffect(() => api.onSessionChange(setUser), []);
  return <AuthContext.Provider value={user}>{children}</AuthContext.Provider>;
}

export function useCurrentUser(): SessionUser | null {
  return useContext(AuthContext);
}

/** Chỉ để điều hướng; quyền thật do backend kiểm tra ở mọi request /admin/**. */
export function RequireAdmin({ children }: { children: ReactNode }) {
  const user = useCurrentUser();
  const location = useLocation();
  if (!user || user.role !== 'ADMIN') {
    return <Navigate to="/login" replace state={{ from: location.pathname }} />;
  }
  return <>{children}</>;
}
