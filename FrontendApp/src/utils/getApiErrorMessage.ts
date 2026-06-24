import type { FetchBaseQueryError } from '@reduxjs/toolkit/query';

interface ApiErrorBody {
  error?: { code?: string; message?: string };
}

/** Extracts a human-readable message from an RTK Query error. */
export function getApiErrorMessage(
  error: unknown,
  fallback = 'Something went wrong. Please try again.',
): string {
  if (typeof error === 'object' && error !== null && 'status' in error) {
    const fbqError = error as FetchBaseQueryError;
    if (fbqError.status === 'FETCH_ERROR') {
      return 'Cannot reach the server. Is the API running?';
    }
    const body = fbqError.data as ApiErrorBody | undefined;
    if (body?.error?.message) {
      return body.error.message;
    }
  }
  return fallback;
}
