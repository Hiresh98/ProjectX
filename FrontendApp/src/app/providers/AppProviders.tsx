import { useMemo, type ReactNode } from 'react';
import { Provider } from 'react-redux';
import { ThemeProvider } from '@mui/material/styles';
import CssBaseline from '@mui/material/CssBaseline';
import { store } from '@/store/store';
import { useAppSelector } from '@/store/hooks';
import { buildTheme } from '@/app/theme';
import { ErrorBoundary } from '@/components/ErrorBoundary';
import { AuthBootstrap } from '@/app/AuthBootstrap';

/** Bridges the Redux-held theme mode into MUI's ThemeProvider. */
function ThemeBridge({ children }: { children: ReactNode }) {
  const mode = useAppSelector((s) => s.ui.themeMode);
  const theme = useMemo(() => buildTheme(mode), [mode]);

  return (
    <ThemeProvider theme={theme}>
      <CssBaseline />
      {children}
    </ThemeProvider>
  );
}

/**
 * Composition root for global providers. Order matters: the Redux store wraps
 * everything; the theme bridge and auth bootstrap both read from it.
 */
export function AppProviders({ children }: { children: ReactNode }) {
  return (
    <Provider store={store}>
      <ThemeBridge>
        <ErrorBoundary>
          <AuthBootstrap>{children}</AuthBootstrap>
        </ErrorBoundary>
      </ThemeBridge>
    </Provider>
  );
}
