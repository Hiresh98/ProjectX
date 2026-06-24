import { configureStore } from '@reduxjs/toolkit';
import { baseApi } from '@/services/baseApi';
import { authReducer } from './authSlice';
import { uiReducer } from './uiSlice';

/**
 * Store factory. Exported so tests can spin up isolated stores; the app uses
 * the shared `store` singleton below.
 */
export function makeStore() {
  return configureStore({
    reducer: {
      [baseApi.reducerPath]: baseApi.reducer,
      auth: authReducer,
      ui: uiReducer,
    },
    middleware: (getDefaultMiddleware) =>
      getDefaultMiddleware().concat(baseApi.middleware),
  });
}

export const store = makeStore();

export type AppStore = ReturnType<typeof makeStore>;
export type RootState = ReturnType<AppStore['getState']>;
export type AppDispatch = AppStore['dispatch'];
