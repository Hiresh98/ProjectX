import { Link as RouterLink } from 'react-router-dom';
import Box from '@mui/material/Box';
import Button from '@mui/material/Button';
import Typography from '@mui/material/Typography';
import { useAuth } from '@/hooks/useAuth';
import { getDefaultRouteForRoles } from '@/constants/permissions';

/** 403 — shown when an authenticated user lacks permission for a route. */
export function ForbiddenPage() {
  const { user } = useAuth();
  const home = user ? getDefaultRouteForRoles(user.roles) : '/login';

  return (
    <Box
      sx={{
        minHeight: '100vh',
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        justifyContent: 'center',
        textAlign: 'center',
        p: 3,
        gap: 1,
      }}
    >
      <Typography variant="h2" color="error" sx={{ fontWeight: 800 }}>
        403
      </Typography>
      <Typography variant="h5">Access Denied</Typography>
      <Typography color="text.secondary" sx={{ mb: 2 }}>
        You don&apos;t have permission to view this page.
      </Typography>
      <Button component={RouterLink} to={home} variant="contained">
        Back to my dashboard
      </Button>
    </Box>
  );
}

export default ForbiddenPage;
