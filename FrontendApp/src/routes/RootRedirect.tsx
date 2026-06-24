import { Navigate } from 'react-router-dom';
import { useAuth } from '@/hooks/useAuth';
import { getDefaultRouteForRoles } from '@/constants/permissions';

/** Sends an authenticated user from "/" to their role's default dashboard. */
export function RootRedirect() {
  const { user } = useAuth();
  if (!user) return <Navigate to="/login" replace />;
  return <Navigate to={getDefaultRouteForRoles(user.roles)} replace />;
}
