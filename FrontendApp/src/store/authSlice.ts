import { createSlice, type PayloadAction } from '@reduxjs/toolkit';
import type { AuthUser } from '@/types/auth';

type AuthStatus = 'initializing' | 'authenticated' | 'unauthenticated';

interface AuthState {
  user: AuthUser | null;
  accessToken: string | null;
  status: AuthStatus;
}

const initialState: AuthState = {
  user: null,
  accessToken: null,
  // Start as "initializing" so guards wait for the silent-refresh bootstrap
  // before deciding to redirect to /login.
  status: 'initializing',
};

const authSlice = createSlice({
  name: 'auth',
  initialState,
  reducers: {
    setCredentials(
      state,
      action: PayloadAction<{ accessToken: string; user: AuthUser }>,
    ) {
      state.accessToken = action.payload.accessToken;
      state.user = action.payload.user;
      state.status = 'authenticated';
    },
    clearCredentials(state) {
      state.accessToken = null;
      state.user = null;
      state.status = 'unauthenticated';
    },
    setUnauthenticated(state) {
      state.status = 'unauthenticated';
    },
  },
});

export const { setCredentials, clearCredentials, setUnauthenticated } =
  authSlice.actions;

export const authReducer = authSlice.reducer;
