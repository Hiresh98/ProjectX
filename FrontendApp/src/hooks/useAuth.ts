import { useAppSelector } from '@/store/hooks';

/** Convenience selector for the current auth state. */
export function useAuth() {
  const { user, status, accessToken } = useAppSelector((s) => s.auth);
  return {
    user,
    status,
    accessToken,
    isAuthenticated: status === 'authenticated' && Boolean(user),
    isInitializing: status === 'initializing',
  };
}
