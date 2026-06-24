import { useEffect, type ReactNode } from 'react';
import Box from '@mui/material/Box';
import CircularProgress from '@mui/material/CircularProgress';
import { config } from '@/lib/config/env';
import { useAppDispatch, useAppSelector } from '@/store/hooks';
import { setCredentials, setUnauthenticated } from '@/store/authSlice';
import type { ApiEnvelope, AuthResponse } from '@/types/auth';

/**
 * Attempts a silent refresh on app load to restore the session from the
 * httpOnly refresh cookie. Done with a raw fetch (not RTK Query) to avoid the
 * baseQuery's reauth interceptor looping on the refresh call itself.
 *
 * Guards render `null` while `status === 'initializing'`, so we show a global
 * splash spinner until this resolves.
 */
export function AuthBootstrap({ children }: { children: ReactNode }) {
  const dispatch = useAppDispatch();
  const status = useAppSelector((s) => s.auth.status);

  useEffect(() => {
    let cancelled = false;

    async function bootstrap(): Promise<void> {
      try {
        const res = await fetch(`${config.apiBaseUrl}/auth/refresh`, {
          method: 'POST',
          credentials: 'include',
        });
        if (!res.ok) throw new Error('no session');
        const json = (await res.json()) as ApiEnvelope<AuthResponse>;
        if (!cancelled) dispatch(setCredentials(json.data));
      } catch {
        if (!cancelled) dispatch(setUnauthenticated());
      }
    }

    void bootstrap();
    return () => {
      cancelled = true;
    };
  }, [dispatch]);

  if (status === 'initializing') {
    return (
      <Box
        sx={{
          minHeight: '100vh',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
        }}
      >
        <CircularProgress />
      </Box>
    );
  }

  return <>{children}</>;
}
