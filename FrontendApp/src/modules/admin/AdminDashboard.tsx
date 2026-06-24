import Box from '@mui/material/Box';
import { PageHeader } from '@/components/PageHeader';
import { StatCard } from '@/components/StatCard';
import { useAuth } from '@/hooks/useAuth';

export function AdminDashboard() {
  const { user } = useAuth();
  return (
    <Box>
      <PageHeader
        title="Super Admin"
        subtitle={`Welcome back, ${user?.firstName ?? ''}`}
      />
      <Box sx={{ display: 'flex', gap: 2, flexWrap: 'wrap' }}>
        <StatCard label="Total Users" value="—" hint="user management" />
        <StatCard label="Roles" value="4" hint="role management" />
        <StatCard label="Active Sessions" value="—" hint="audit logs" />
        <StatCard label="System Health" value="OK" hint="settings" />
      </Box>
    </Box>
  );
}

export default AdminDashboard;
