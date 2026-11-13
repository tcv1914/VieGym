import { Navigate, Route, Routes } from 'react-router-dom';
import { RequireAdmin } from './auth/AuthContext';
import { Layout } from './components/Layout';
import { ExercisesPage } from './pages/ExercisesPage';
import { FoodsPage } from './pages/FoodsPage';
import { LoginPage } from './pages/LoginPage';
import { UsersPage } from './pages/UsersPage';

export function App() {
  return (
    <Routes>
      <Route path="/login" element={<LoginPage />} />
      <Route
        element={
          <RequireAdmin>
            <Layout />
          </RequireAdmin>
        }
      >
        <Route path="/foods" element={<FoodsPage />} />
        <Route path="/exercises" element={<ExercisesPage />} />
        <Route path="/users" element={<UsersPage />} />
      </Route>
      <Route path="*" element={<Navigate to="/foods" replace />} />
    </Routes>
  );
}
