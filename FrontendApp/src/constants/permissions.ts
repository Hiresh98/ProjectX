/**
 * Frontend mirror of the backend RBAC keys (BackendApp/src/constants/permissions.ts).
 * The server is always authoritative; these keys exist only to drive UX
 * (hiding menus, disabling actions, guarding routes for a better experience).
 */

export const ROLES = {
  SUPER_ADMIN: 'SUPER_ADMIN',
  ACCOUNT_MANAGER: 'ACCOUNT_MANAGER',
  HR_MANAGER: 'HR_MANAGER',
  CLIENT: 'CLIENT',
} as const;

export type RoleKey = (typeof ROLES)[keyof typeof ROLES];

export const PERMISSIONS = {
  DASHBOARD_VIEW: 'dashboard:view',

  USER_READ: 'user:read',
  USER_CREATE: 'user:create',
  USER_UPDATE: 'user:update',
  USER_DELETE: 'user:delete',

  ROLE_READ: 'role:read',
  ROLE_UPDATE: 'role:update',

  SETTINGS_MANAGE: 'settings:manage',
  AUDIT_READ: 'audit:read',
  REPORT_READ: 'report:read',

  CLIENT_READ: 'client:read',
  CLIENT_CREATE: 'client:create',
  CLIENT_UPDATE: 'client:update',

  PROJECT_READ: 'project:read',
  PROJECT_CREATE: 'project:create',
  PROJECT_UPDATE: 'project:update',

  REVENUE_READ: 'revenue:read',
  TASK_READ: 'task:read',
  TASK_CREATE: 'task:create',
  TASK_UPDATE: 'task:update',

  EMPLOYEE_READ: 'employee:read',
  EMPLOYEE_CREATE: 'employee:create',
  EMPLOYEE_UPDATE: 'employee:update',

  ATTENDANCE_READ: 'attendance:read',
  ATTENDANCE_MANAGE: 'attendance:manage',

  LEAVE_READ: 'leave:read',
  LEAVE_APPROVE: 'leave:approve',
  LEAVE_REJECT: 'leave:reject',

  RECRUITMENT_MANAGE: 'recruitment:manage',
  PAYROLL_READ: 'payroll:read',

  DOCUMENT_READ: 'document:read',
  DOCUMENT_UPLOAD: 'document:upload',
  DOCUMENT_DOWNLOAD: 'document:download',

  TICKET_READ: 'ticket:read',
  TICKET_CREATE: 'ticket:create',

  INVOICE_READ: 'invoice:read',
} as const;

export type PermissionKey = (typeof PERMISSIONS)[keyof typeof PERMISSIONS];

/** Default landing route per role (post-login redirect). */
export const ROLE_HOME_ROUTE: Record<RoleKey, string> = {
  [ROLES.SUPER_ADMIN]: '/admin',
  [ROLES.ACCOUNT_MANAGER]: '/account-manager',
  [ROLES.HR_MANAGER]: '/hr',
  [ROLES.CLIENT]: '/client',
};

/** Resolve where a user should land based on their (first) role. */
export function getDefaultRouteForRoles(roles: RoleKey[]): string {
  const first = roles[0];
  return first ? (ROLE_HOME_ROUTE[first] ?? '/') : '/login';
}
