import { render, screen } from '@testing-library/react';
import { Provider } from 'react-redux';
import { MemoryRouter, Route, Routes } from 'react-router-dom';
import { describe, expect, it } from 'vitest';
import { makeStore } from '@/store/store';
import { setCredentials } from '@/store/authSlice';
import { RoleProtectedRoute } from './RoleProtectedRoute';
import { PERMISSIONS, ROLES } from '@/constants/permissions';
import type { AuthUser } from '@/types/auth';
import type { PermissionKey } from '@/constants/permissions';

function renderWithPermissions(permissions: PermissionKey[]) {
  const store = makeStore();
  const user: AuthUser = {
    id: 'u1',
    email: 'user@projectx.dev',
    firstName: 'Test',
    lastName: 'User',
    roles: [ROLES.SUPER_ADMIN],
    permissions,
  };
  store.dispatch(setCredentials({ accessToken: 'test-token', user }));

  return render(
    <Provider store={store}>
      <MemoryRouter initialEntries={['/secret']}>
        <Routes>
          <Route
            element={
              <RoleProtectedRoute
                requiredPermissions={[PERMISSIONS.USER_READ]}
              />
            }
          >
            <Route path="/secret" element={<div>secret content</div>} />
          </Route>
          <Route path="/403" element={<div>access denied</div>} />
        </Routes>
      </MemoryRouter>
    </Provider>,
  );
}

describe('RoleProtectedRoute', () => {
  it('renders the nested route when the user has the permission', () => {
    renderWithPermissions([PERMISSIONS.USER_READ]);
    expect(screen.getByText('secret content')).toBeInTheDocument();
  });

  it('redirects to /403 when the permission is missing', () => {
    renderWithPermissions([PERMISSIONS.DASHBOARD_VIEW]);
    expect(screen.getByText('access denied')).toBeInTheDocument();
    expect(screen.queryByText('secret content')).not.toBeInTheDocument();
  });
});
