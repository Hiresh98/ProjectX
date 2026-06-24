import { baseApi } from './baseApi';
import type { ApiEnvelope, AuthResponse, AuthUser } from '@/types/auth';

interface LoginRequest {
  email: string;
  password: string;
}

interface ForgotPasswordRequest {
  email: string;
}

interface ResetPasswordRequest {
  token: string;
  password: string;
}

interface ChangePasswordRequest {
  currentPassword: string;
  newPassword: string;
}

export const authApi = baseApi.injectEndpoints({
  endpoints: (build) => ({
    login: build.mutation<AuthResponse, LoginRequest>({
      query: (body) => ({ url: '/auth/login', method: 'POST', body }),
      transformResponse: (res: ApiEnvelope<AuthResponse>) => res.data,
      invalidatesTags: ['Me'],
    }),

    logout: build.mutation<void, void>({
      query: () => ({ url: '/auth/logout', method: 'POST' }),
    }),

    me: build.query<AuthUser, void>({
      query: () => ({ url: '/auth/me' }),
      transformResponse: (res: ApiEnvelope<{ user: AuthUser }>) =>
        res.data.user,
      providesTags: ['Me'],
    }),

    forgotPassword: build.mutation<
      { message: string; devResetUrl?: string },
      ForgotPasswordRequest
    >({
      query: (body) => ({ url: '/auth/forgot-password', method: 'POST', body }),
      transformResponse: (
        res: ApiEnvelope<{ message: string; devResetUrl?: string }>,
      ) => res.data,
    }),

    resetPassword: build.mutation<{ message: string }, ResetPasswordRequest>({
      query: (body) => ({ url: '/auth/reset-password', method: 'POST', body }),
      transformResponse: (res: ApiEnvelope<{ message: string }>) => res.data,
    }),

    changePassword: build.mutation<{ message: string }, ChangePasswordRequest>({
      query: (body) => ({ url: '/auth/change-password', method: 'POST', body }),
      transformResponse: (res: ApiEnvelope<{ message: string }>) => res.data,
    }),
  }),
  overrideExisting: false,
});

export const {
  useLoginMutation,
  useLogoutMutation,
  useMeQuery,
  useForgotPasswordMutation,
  useResetPasswordMutation,
  useChangePasswordMutation,
} = authApi;
