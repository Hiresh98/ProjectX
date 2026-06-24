import type { PermissionKey, RoleKey } from '@/constants/permissions';

export interface AuthUser {
  id: string;
  email: string;
  firstName: string;
  lastName: string;
  roles: RoleKey[];
  permissions: PermissionKey[];
}

export interface AuthResponse {
  accessToken: string;
  user: AuthUser;
}

/** Standard success envelope from the API. */
export interface ApiEnvelope<T> {
  data: T;
}
