import { describe, expect, it } from 'vitest';
import {
  authReducer,
  clearCredentials,
  setCredentials,
  setUnauthenticated,
} from './authSlice';
import { ROLES, PERMISSIONS } from '@/constants/permissions';
import type { AuthUser } from '@/types/auth';

const user: AuthUser = {
  id: 'u1',
  email: 'admin@projectx.dev',
  firstName: 'Super',
  lastName: 'Admin',
  roles: [ROLES.SUPER_ADMIN],
  permissions: [PERMISSIONS.USER_READ],
};

describe('authSlice', () => {
  it('starts in initializing state', () => {
    const state = authReducer(undefined, { type: '@@INIT' });
    expect(state.status).toBe('initializing');
    expect(state.user).toBeNull();
  });

  it('setCredentials authenticates and stores user + token', () => {
    const state = authReducer(
      undefined,
      setCredentials({ accessToken: 'token-abc', user }),
    );
    expect(state.status).toBe('authenticated');
    expect(state.accessToken).toBe('token-abc');
    expect(state.user?.email).toBe('admin@projectx.dev');
  });

  it('clearCredentials logs out', () => {
    const authed = authReducer(
      undefined,
      setCredentials({ accessToken: 't', user }),
    );
    const state = authReducer(authed, clearCredentials());
    expect(state.status).toBe('unauthenticated');
    expect(state.user).toBeNull();
    expect(state.accessToken).toBeNull();
  });

  it('setUnauthenticated marks the bootstrap as resolved', () => {
    const state = authReducer(undefined, setUnauthenticated());
    expect(state.status).toBe('unauthenticated');
  });
});
