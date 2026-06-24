import {
  createApi,
  fetchBaseQuery,
  type BaseQueryFn,
  type FetchArgs,
  type FetchBaseQueryError,
} from '@reduxjs/toolkit/query/react';
import { Mutex } from './mutex';
import { config } from '@/lib/config/env';
import { setCredentials, clearCredentials } from '@/store/authSlice';
import type { RootState } from '@/store/store';
import type { ApiEnvelope, AuthResponse } from '@/types/auth';

const rawBaseQuery = fetchBaseQuery({
  baseUrl: config.apiBaseUrl,
  credentials: 'include', // send the httpOnly refresh cookie
  prepareHeaders: (headers, { getState }) => {
    const token = (getState() as RootState).auth.accessToken;
    if (token) {
      headers.set('Authorization', `Bearer ${token}`);
    }
    return headers;
  },
});

// A single mutex serializes refresh attempts so a burst of 401s triggers only
// one /auth/refresh call; other requests wait and then retry.
const refreshMutex = new Mutex();

/**
 * Wraps the base query: on a 401, attempts a token refresh once (guarded by a
 * mutex), then replays the original request. If refresh fails, credentials are
 * cleared so the route guards send the user to /login.
 */
export const baseQueryWithReauth: BaseQueryFn<
  string | FetchArgs,
  unknown,
  FetchBaseQueryError
> = async (args, api, extraOptions) => {
  await refreshMutex.waitForUnlock();
  let result = await rawBaseQuery(args, api, extraOptions);

  if (result.error?.status === 401) {
    if (!refreshMutex.isLocked()) {
      const release = await refreshMutex.acquire();
      try {
        const refresh = await rawBaseQuery(
          { url: '/auth/refresh', method: 'POST' },
          api,
          extraOptions,
        );
        const payload = (refresh.data as ApiEnvelope<AuthResponse> | undefined)
          ?.data;
        if (payload) {
          api.dispatch(setCredentials(payload));
          result = await rawBaseQuery(args, api, extraOptions);
        } else {
          api.dispatch(clearCredentials());
        }
      } finally {
        release();
      }
    } else {
      await refreshMutex.waitForUnlock();
      result = await rawBaseQuery(args, api, extraOptions);
    }
  }

  return result;
};

export const baseApi = createApi({
  reducerPath: 'api',
  baseQuery: baseQueryWithReauth,
  tagTypes: ['User', 'Role', 'Client', 'Project', 'Employee', 'Me'],
  endpoints: () => ({}),
});
