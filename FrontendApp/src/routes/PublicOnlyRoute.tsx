import { Navigate, Outlet } from 'react-router-dom';
import { useAuth } from '@/hooks/useAuth';
import { getDefaultRouteForRoles } from '@/constants/permissions';

/**
 * For pages that should not be seen while logged in (e.g. /login). Redirects
 * authenticated users to their role's default dashboard.
 */
export function PublicOnlyRoute() {
  const { isAuthenticated, user } = useAuth();

  if (isAuthenticated && user) {
    return <Navigate to={getDefaultRouteForRoles(user.roles)} replace />;
  }

  return <Outlet />;
}
