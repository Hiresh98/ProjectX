import { createSlice, type PayloadAction } from '@reduxjs/toolkit';

export type ThemeMode = 'light' | 'dark';

const STORAGE_KEY = 'projectx.themeMode';

function readInitialMode(): ThemeMode {
  if (typeof window === 'undefined') return 'light';
  const stored = window.localStorage.getItem(STORAGE_KEY);
  if (stored === 'light' || stored === 'dark') return stored;
  if (typeof window.matchMedia === 'function') {
    return window.matchMedia('(prefers-color-scheme: dark)').matches
      ? 'dark'
      : 'light';
  }
  return 'light';
}

interface UiState {
  themeMode: ThemeMode;
  sidebarOpen: boolean;
}

const initialState: UiState = {
  themeMode: readInitialMode(),
  sidebarOpen: true,
};

const uiSlice = createSlice({
  name: 'ui',
  initialState,
  reducers: {
    toggleThemeMode(state) {
      state.themeMode = state.themeMode === 'light' ? 'dark' : 'light';
      window.localStorage.setItem(STORAGE_KEY, state.themeMode);
    },
    setThemeMode(state, action: PayloadAction<ThemeMode>) {
      state.themeMode = action.payload;
      window.localStorage.setItem(STORAGE_KEY, state.themeMode);
    },
    toggleSidebar(state) {
      state.sidebarOpen = !state.sidebarOpen;
    },
  },
});

export const { toggleThemeMode, setThemeMode, toggleSidebar } = uiSlice.actions;
export const uiReducer = uiSlice.reducer;
