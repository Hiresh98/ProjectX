import { Navigate, Outlet } from 'react-router-dom';
import { usePermissions } from '@/hooks/usePermissions';
import type { PermissionKey } from '@/constants/permissions';

interface RoleProtectedRouteProps {
  /** All of these permissions are required to view the nested routes. */
  requiredPermissions: PermissionKey[];
}

/**
 * Permission gate. Assumes it is nested inside <ProtectedRoute> (so the user is
 * already authenticated). Sends users lacking the permission to /403.
 *
 * This is UX-only — the API independently enforces the same permissions.
 */
export function RoleProtectedRoute({
  requiredPermissions,
}: RoleProtectedRouteProps) {
  const { hasAll } = usePermissions();

  if (!hasAll(requiredPermissions)) {
    return <Navigate to="/403" replace />;
  }

  return <Outlet />;
}
