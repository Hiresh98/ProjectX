import Box from '@mui/material/Box';
import { PageHeader } from '@/components/PageHeader';
import { StatCard } from '@/components/StatCard';
import { useAuth } from '@/hooks/useAuth';

export function HrDashboard() {
  const { user } = useAuth();
  return (
    <Box>
      <PageHeader
        title="HR Manager"
        subtitle={`Welcome back, ${user?.firstName ?? ''}`}
      />
      <Box sx={{ display: 'flex', gap: 2, flexWrap: 'wrap' }}>
        <StatCard label="Employees" value="—" hint="directory" />
        <StatCard label="Present Today" value="—" hint="attendance" />
        <StatCard label="Pending Leave" value="—" hint="leave requests" />
        <StatCard label="Open Roles" value="—" hint="recruitment" />
      </Box>
    </Box>
  );
}

export default HrDashboard;
