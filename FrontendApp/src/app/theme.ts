import { createTheme, type Theme } from '@mui/material/styles';
import type { ThemeMode } from '@/store/uiSlice';

/** Builds the MUI theme for the given mode. Memoize at the call site. */
export function buildTheme(mode: ThemeMode): Theme {
  return createTheme({
    palette: {
      mode,
      primary: { main: '#4f46e5' },
      secondary: { main: '#0ea5e9' },
    },
    shape: { borderRadius: 10 },
    typography: {
      fontFamily:
        'system-ui, -apple-system, "Segoe UI", Roboto, Helvetica, Arial, sans-serif',
    },
  });
}
