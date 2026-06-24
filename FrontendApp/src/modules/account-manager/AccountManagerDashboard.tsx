import Box from '@mui/material/Box';
import { PageHeader } from '@/components/PageHeader';
import { StatCard } from '@/components/StatCard';
import { useAuth } from '@/hooks/useAuth';

export function AccountManagerDashboard() {
  const { user } = useAuth();
  return (
    <Box>
      <PageHeader
        title="Account Manager"
        subtitle={`Welcome back, ${user?.firstName ?? ''}`}
      />
      <Box sx={{ display: 'flex', gap: 2, flexWrap: 'wrap' }}>
        <StatCard label="Clients" value="—" hint="client management" />
        <StatCard label="Active Projects" value="—" hint="project tracking" />
        <StatCard label="Revenue (MTD)" value="—" hint="revenue tracking" />
        <StatCard label="Open Tasks" value="—" hint="task management" />
      </Box>
    </Box>
  );
}

export default AccountManagerDashboard;
