import type { SvgIconComponent } from '@mui/icons-material';
import DashboardIcon from '@mui/icons-material/Dashboard';
import PeopleIcon from '@mui/icons-material/People';
import SecurityIcon from '@mui/icons-material/Security';
import AssessmentIcon from '@mui/icons-material/Assessment';
import HistoryIcon from '@mui/icons-material/History';
import SettingsIcon from '@mui/icons-material/Settings';
import BusinessIcon from '@mui/icons-material/Business';
import WorkIcon from '@mui/icons-material/Work';
import PaidIcon from '@mui/icons-material/Paid';
import BadgeIcon from '@mui/icons-material/Badge';
import AccessTimeIcon from '@mui/icons-material/AccessTime';
import EventNoteIcon from '@mui/icons-material/EventNote';
import DescriptionIcon from '@mui/icons-material/Description';
import ConfirmationNumberIcon from '@mui/icons-material/ConfirmationNumber';
import {
  PERMISSIONS,
  ROLES,
  type PermissionKey,
  type RoleKey,
} from './permissions';

export interface MenuItem {
  label: string;
  path: string;
  icon: SvgIconComponent;
  permission: PermissionKey;
}

/**
 * Menu sections keyed by role area. The sidebar selects the section for the
 * user's role, then hides any item whose permission the user lacks — so the
 * menu is fully permission-driven even within an area.
 */
export const MENU_SECTIONS: Record<RoleKey, MenuItem[]> = {
  [ROLES.SUPER_ADMIN]: [
    {
      label: 'Dashboard',
      path: '/admin',
      icon: DashboardIcon,
      permission: PERMISSIONS.DASHBOARD_VIEW,
    },
    {
      label: 'Users',
      path: '/admin/users',
      icon: PeopleIcon,
      permission: PERMISSIONS.USER_READ,
    },
    {
      label: 'Roles',
      path: '/admin/roles',
      icon: SecurityIcon,
      permission: PERMISSIONS.ROLE_READ,
    },
    {
      label: 'Reports',
      path: '/admin/reports',
      icon: AssessmentIcon,
      permission: PERMISSIONS.REPORT_READ,
    },
    {
      label: 'Audit Logs',
      path: '/admin/audit',
      icon: HistoryIcon,
      permission: PERMISSIONS.AUDIT_READ,
    },
    {
      label: 'Settings',
      path: '/admin/settings',
      icon: SettingsIcon,
      permission: PERMISSIONS.SETTINGS_MANAGE,
    },
  ],
  [ROLES.ACCOUNT_MANAGER]: [
    {
      label: 'Dashboard',
      path: '/account-manager',
      icon: DashboardIcon,
      permission: PERMISSIONS.DASHBOARD_VIEW,
    },
    {
      label: 'Clients',
      path: '/account-manager/clients',
      icon: BusinessIcon,
      permission: PERMISSIONS.CLIENT_READ,
    },
    {
      label: 'Projects',
      path: '/account-manager/projects',
      icon: WorkIcon,
      permission: PERMISSIONS.PROJECT_READ,
    },
    {
      label: 'Revenue',
      path: '/account-manager/revenue',
      icon: PaidIcon,
      permission: PERMISSIONS.REVENUE_READ,
    },
  ],
  [ROLES.HR_MANAGER]: [
    {
      label: 'Dashboard',
      path: '/hr',
      icon: DashboardIcon,
      permission: PERMISSIONS.DASHBOARD_VIEW,
    },
    {
      label: 'Employees',
      path: '/hr/employees',
      icon: BadgeIcon,
      permission: PERMISSIONS.EMPLOYEE_READ,
    },
    {
      label: 'Attendance',
      path: '/hr/attendance',
      icon: AccessTimeIcon,
      permission: PERMISSIONS.ATTENDANCE_READ,
    },
    {
      label: 'Leave Requests',
      path: '/hr/leave',
      icon: EventNoteIcon,
      permission: PERMISSIONS.LEAVE_READ,
    },
  ],
  [ROLES.CLIENT]: [
    {
      label: 'Dashboard',
      path: '/client',
      icon: DashboardIcon,
      permission: PERMISSIONS.DASHBOARD_VIEW,
    },
    {
      label: 'My Projects',
      path: '/client/projects',
      icon: WorkIcon,
      permission: PERMISSIONS.PROJECT_READ,
    },
    {
      label: 'Documents',
      path: '/client/documents',
      icon: DescriptionIcon,
      permission: PERMISSIONS.DOCUMENT_READ,
    },
    {
      label: 'Tickets',
      path: '/client/tickets',
      icon: ConfirmationNumberIcon,
      permission: PERMISSIONS.TICKET_READ,
    },
  ],
};
