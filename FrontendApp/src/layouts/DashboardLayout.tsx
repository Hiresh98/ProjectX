import { Suspense, useState } from 'react';
import { Outlet, useLocation, useNavigate } from 'react-router-dom';
import AppBar from '@mui/material/AppBar';
import Avatar from '@mui/material/Avatar';
import Box from '@mui/material/Box';
import CircularProgress from '@mui/material/CircularProgress';
import Divider from '@mui/material/Divider';
import Drawer from '@mui/material/Drawer';
import IconButton from '@mui/material/IconButton';
import List from '@mui/material/List';
import ListItemButton from '@mui/material/ListItemButton';
import ListItemIcon from '@mui/material/ListItemIcon';
import ListItemText from '@mui/material/ListItemText';
import Menu from '@mui/material/Menu';
import MenuItem from '@mui/material/MenuItem';
import Toolbar from '@mui/material/Toolbar';
import Typography from '@mui/material/Typography';
import useMediaQuery from '@mui/material/useMediaQuery';
import { useTheme } from '@mui/material/styles';
import MenuIcon from '@mui/icons-material/Menu';
import DarkModeIcon from '@mui/icons-material/DarkMode';
import LightModeIcon from '@mui/icons-material/LightMode';
import { ErrorBoundary } from '@/components/ErrorBoundary';
import { config } from '@/lib/config/env';
import { MENU_SECTIONS } from '@/constants/menu';
import { useAuth } from '@/hooks/useAuth';
import { usePermissions } from '@/hooks/usePermissions';
import { useAppDispatch, useAppSelector } from '@/store/hooks';
import { toggleThemeMode } from '@/store/uiSlice';
import { clearCredentials } from '@/store/authSlice';
import { useLogoutMutation } from '@/services/authApi';

const DRAWER_WIDTH = 248;

export function DashboardLayout() {
  const theme = useTheme();
  const isDesktop = useMediaQuery(theme.breakpoints.up('md'));
  const [mobileOpen, setMobileOpen] = useState(false);
  const [anchorEl, setAnchorEl] = useState<null | HTMLElement>(null);

  const navigate = useNavigate();
  const location = useLocation();
  const dispatch = useAppDispatch();
  const { user } = useAuth();
  const { has } = usePermissions();
  const themeMode = useAppSelector((s) => s.ui.themeMode);
  const [logout] = useLogoutMutation();

  const primaryRole = user?.roles[0];
  const items = (primaryRole ? MENU_SECTIONS[primaryRole] : []).filter((item) =>
    has(item.permission),
  );

  const handleNavigate = (path: string): void => {
    navigate(path);
    if (!isDesktop) setMobileOpen(false);
  };

  const handleLogout = async (): Promise<void> => {
    setAnchorEl(null);
    try {
      await logout().unwrap();
    } catch {
      // Even if the network call fails, clear local state.
    }
    dispatch(clearCredentials());
    navigate('/login', { replace: true });
  };

  const isSelected = (path: string): boolean =>
    location.pathname === path ||
    (path !== `/${primaryRole?.toLowerCase()}` &&
      location.pathname.startsWith(`${path}/`));

  const drawerContent = (
    <Box role="navigation" aria-label="Sidebar">
      <Toolbar>
        <Typography variant="h6" noWrap sx={{ fontWeight: 700 }}>
          {config.appName}
        </Typography>
      </Toolbar>
      <Divider />
      <List>
        {items.map((item) => {
          const Icon = item.icon;
          return (
            <ListItemButton
              key={item.path}
              selected={isSelected(item.path)}
              onClick={() => handleNavigate(item.path)}
            >
              <ListItemIcon>
                <Icon />
              </ListItemIcon>
              <ListItemText primary={item.label} />
            </ListItemButton>
          );
        })}
      </List>
    </Box>
  );

  return (
    <Box sx={{ display: 'flex', minHeight: '100vh' }}>
      <AppBar
        position="fixed"
        sx={{ zIndex: (t) => t.zIndex.drawer + 1 }}
        elevation={1}
      >
        <Toolbar sx={{ gap: 1 }}>
          {!isDesktop && (
            <IconButton
              color="inherit"
              edge="start"
              aria-label="Open navigation"
              onClick={() => setMobileOpen((o) => !o)}
            >
              <MenuIcon />
            </IconButton>
          )}
          <Typography variant="h6" sx={{ flexGrow: 1 }} noWrap>
            {primaryRole?.replace('_', ' ')} Portal
          </Typography>

          <IconButton
            color="inherit"
            aria-label="Toggle theme"
            onClick={() => dispatch(toggleThemeMode())}
          >
            {themeMode === 'dark' ? <LightModeIcon /> : <DarkModeIcon />}
          </IconButton>

          <IconButton
            color="inherit"
            aria-label="Account menu"
            onClick={(e) => setAnchorEl(e.currentTarget)}
          >
            <Avatar sx={{ width: 32, height: 32, bgcolor: 'secondary.main' }}>
              {user?.firstName?.[0] ?? '?'}
            </Avatar>
          </IconButton>
          <Menu
            anchorEl={anchorEl}
            open={Boolean(anchorEl)}
            onClose={() => setAnchorEl(null)}
          >
            <MenuItem disabled>{user?.email}</MenuItem>
            <Divider />
            <MenuItem
              onClick={() => {
                setAnchorEl(null);
                navigate('/change-password');
              }}
            >
              Change password
            </MenuItem>
            <MenuItem onClick={() => void handleLogout()}>Logout</MenuItem>
          </Menu>
        </Toolbar>
      </AppBar>

      <Box
        component="nav"
        sx={{ width: { md: DRAWER_WIDTH }, flexShrink: { md: 0 } }}
      >
        <Drawer
          variant={isDesktop ? 'permanent' : 'temporary'}
          open={isDesktop ? true : mobileOpen}
          onClose={() => setMobileOpen(false)}
          ModalProps={{ keepMounted: true }}
          sx={{
            '& .MuiDrawer-paper': {
              boxSizing: 'border-box',
              width: DRAWER_WIDTH,
            },
          }}
        >
          {drawerContent}
        </Drawer>
      </Box>

      <Box
        component="main"
        sx={{
          flexGrow: 1,
          p: 3,
          width: { md: `calc(100% - ${DRAWER_WIDTH}px)` },
        }}
      >
        <Toolbar />
        <ErrorBoundary>
          <Suspense
            fallback={
              <Box sx={{ display: 'flex', justifyContent: 'center', p: 4 }}>
                <CircularProgress />
              </Box>
            }
          >
            <Outlet />
          </Suspense>
        </ErrorBoundary>
      </Box>
    </Box>
  );
}
