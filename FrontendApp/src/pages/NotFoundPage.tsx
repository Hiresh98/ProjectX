import { Link as RouterLink } from 'react-router-dom';
import Box from '@mui/material/Box';
import Button from '@mui/material/Button';
import Typography from '@mui/material/Typography';
import { useAuth } from '@/hooks/useAuth';
import { getDefaultRouteForRoles } from '@/constants/permissions';

export function NotFoundPage() {
  const { user } = useAuth();
  const home = user ? getDefaultRouteForRoles(user.roles) : '/login';

  return (
    <Box sx={{ textAlign: 'center', py: 8 }}>
      <Typography variant="h3" sx={{ fontWeight: 800 }}>
        404
      </Typography>
      <Typography color="text.secondary" sx={{ mb: 2 }}>
        This page does not exist.
      </Typography>
      <Button component={RouterLink} to={home} variant="contained">
        Go home
      </Button>
    </Box>
  );
}

export default NotFoundPage;
