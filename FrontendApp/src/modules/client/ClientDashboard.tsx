import Box from '@mui/material/Box';
import { PageHeader } from '@/components/PageHeader';
import { StatCard } from '@/components/StatCard';
import { useAuth } from '@/hooks/useAuth';

export function ClientDashboard() {
  const { user } = useAuth();
  return (
    <Box>
      <PageHeader
        title="Client Portal"
        subtitle={`Welcome back, ${user?.firstName ?? ''}`}
      />
      <Box sx={{ display: 'flex', gap: 2, flexWrap: 'wrap' }}>
        <StatCard label="My Projects" value="—" hint="project status" />
        <StatCard label="Documents" value="—" hint="upload / download" />
        <StatCard label="Open Tickets" value="—" hint="support" />
        <StatCard label="Invoices Due" value="—" hint="billing" />
      </Box>
    </Box>
  );
}

export default ClientDashboard;
