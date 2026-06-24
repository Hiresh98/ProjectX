import { describe, expect, it } from 'vitest';
import { getDefaultRouteForRoles, ROLES } from './permissions';

describe('getDefaultRouteForRoles', () => {
  it('maps each role to its dashboard', () => {
    expect(getDefaultRouteForRoles([ROLES.SUPER_ADMIN])).toBe('/admin');
    expect(getDefaultRouteForRoles([ROLES.ACCOUNT_MANAGER])).toBe(
      '/account-manager',
    );
    expect(getDefaultRouteForRoles([ROLES.HR_MANAGER])).toBe('/hr');
    expect(getDefaultRouteForRoles([ROLES.CLIENT])).toBe('/client');
  });

  it('uses the first role when multiple are present', () => {
    expect(getDefaultRouteForRoles([ROLES.HR_MANAGER, ROLES.CLIENT])).toBe(
      '/hr',
    );
  });

  it('falls back to /login when no roles', () => {
    expect(getDefaultRouteForRoles([])).toBe('/login');
  });
});
