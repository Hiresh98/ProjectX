import { lazy } from 'react';
import { createBrowserRouter, RouterProvider } from 'react-router-dom';
import { AuthLayout } from '@/layouts/AuthLayout';
import { DashboardLayout } from '@/layouts/DashboardLayout';
import { ProtectedRoute } from './ProtectedRoute';
import { PublicOnlyRoute } from './PublicOnlyRoute';
import { RoleProtectedRoute } from './RoleProtectedRoute';
import { RootRedirect } from './RootRedirect';
import { Placeholder } from '@/components/Placeholder';
import { PERMISSIONS } from '@/constants/permissions';

// Route-level code splitting.
const LoginPage = lazy(() => import('@/modules/auth/LoginPage'));
const ForgotPasswordPage = lazy(
  () => import('@/modules/auth/ForgotPasswordPage'),
);
const ResetPasswordPage = lazy(
  () => import('@/modules/auth/ResetPasswordPage'),
);
const ChangePasswordPage = lazy(
  () => import('@/modules/auth/ChangePasswordPage'),
);
const AdminDashboard = lazy(() => import('@/modules/admin/AdminDashboard'));
const AccountManagerDashboard = lazy(
  () => import('@/modules/account-manager/AccountManagerDashboard'),
);
const HrDashboard = lazy(() => import('@/modules/hr/HrDashboard'));
const ClientDashboard = lazy(() => import('@/modules/client/ClientDashboard'));
const ForbiddenPage = lazy(() => import('@/pages/ForbiddenPage'));
const NotFoundPage = lazy(() => import('@/pages/NotFoundPage'));

const router = createBrowserRouter([
  {
    element: <PublicOnlyRoute />,
    children: [
      {
        element: <AuthLayout />,
        children: [
          { path: '/login', element: <LoginPage /> },
          { path: '/forgot-password', element: <ForgotPasswordPage /> },
          { path: '/reset-password', element: <ResetPasswordPage /> },
        ],
      },
    ],
  },

  { path: '/403', element: <ForbiddenPage /> },

  {
    element: <ProtectedRoute />,
    children: [
      {
        element: <DashboardLayout />,
        children: [
          { index: true, element: <RootRedirect /> },
          { path: 'change-password', element: <ChangePasswordPage /> },

          // ── Super Admin area ──
          {
            element: (
              <RoleProtectedRoute
                requiredPermissions={[PERMISSIONS.USER_READ]}
              />
            ),
            children: [
              { path: 'admin', element: <AdminDashboard /> },
              { path: 'admin/users', element: <Placeholder title="Users" /> },
              { path: 'admin/roles', element: <Placeholder title="Roles" /> },
              {
                path: 'admin/reports',
                element: <Placeholder title="Reports" />,
              },
              {
                path: 'admin/audit',
                element: <Placeholder title="Audit Logs" />,
              },
              {
                path: 'admin/settings',
                element: <Placeholder title="Settings" />,
              },
            ],
          },

          // ── Account Manager area ──
          {
            element: (
              <RoleProtectedRoute
                requiredPermissions={[PERMISSIONS.CLIENT_READ]}
              />
            ),
            children: [
              { path: 'account-manager', element: <AccountManagerDashboard /> },
              {
                path: 'account-manager/clients',
                element: <Placeholder title="Clients" />,
              },
              {
                path: 'account-manager/projects',
                element: <Placeholder title="Projects" />,
              },
              {
                path: 'account-manager/revenue',
                element: <Placeholder title="Revenue" />,
              },
            ],
          },

          // ── HR area ──
          {
            element: (
              <RoleProtectedRoute
                requiredPermissions={[PERMISSIONS.EMPLOYEE_READ]}
              />
            ),
            children: [
              { path: 'hr', element: <HrDashboard /> },
              {
                path: 'hr/employees',
                element: <Placeholder title="Employees" />,
              },
              {
                path: 'hr/attendance',
                element: <Placeholder title="Attendance" />,
              },
              {
                path: 'hr/leave',
                element: <Placeholder title="Leave Requests" />,
              },
            ],
          },

          // ── Client area ──
          {
            element: (
              <RoleProtectedRoute
                requiredPermissions={[PERMISSIONS.TICKET_READ]}
              />
            ),
            children: [
              { path: 'client', element: <ClientDashboard /> },
              {
                path: 'client/projects',
                element: <Placeholder title="My Projects" />,
              },
              {
                path: 'client/documents',
                element: <Placeholder title="Documents" />,
              },
              {
                path: 'client/tickets',
                element: <Placeholder title="Tickets" />,
              },
            ],
          },

          { path: '*', element: <NotFoundPage /> },
        ],
      },
    ],
  },
]);

export function AppRouter() {
  return <RouterProvider router={router} />;
}
