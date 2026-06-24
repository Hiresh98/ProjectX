import { Outlet } from 'react-router-dom';
import Box from '@mui/material/Box';
import Paper from '@mui/material/Paper';
import Typography from '@mui/material/Typography';
import { config } from '@/lib/config/env';

/** Centered shell for unauthenticated pages (login, forgot/reset password). */
export function AuthLayout() {
  return (
    <Box
      sx={{
        minHeight: '100vh',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        bgcolor: 'background.default',
        p: 2,
      }}
    >
      <Paper sx={{ p: 4, width: '100%', maxWidth: 420 }} elevation={3}>
        <Typography variant="h5" gutterBottom sx={{ fontWeight: 700 }}>
          {config.appName}
        </Typography>
        <Outlet />
      </Paper>
    </Box>
  );
}
