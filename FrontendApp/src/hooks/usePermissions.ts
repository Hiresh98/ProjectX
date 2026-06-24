import { useMemo } from 'react';
import { useAppSelector } from '@/store/hooks';
import type { PermissionKey } from '@/constants/permissions';

/**
 * Permission helpers derived from the authenticated user. Memoized so the
 * returned object is stable across renders.
 */
export function usePermissions() {
  const permissions = useAppSelector((s) => s.auth.user?.permissions);

  return useMemo(() => {
    const set = new Set(permissions ?? []);
    return {
      has: (permission: PermissionKey) => set.has(permission),
      hasAll: (required: PermissionKey[]) => required.every((p) => set.has(p)),
      hasAny: (required: PermissionKey[]) => required.some((p) => set.has(p)),
    };
  }, [permissions]);
}
