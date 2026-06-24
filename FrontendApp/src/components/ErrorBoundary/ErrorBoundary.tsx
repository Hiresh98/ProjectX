import { Component, type ErrorInfo, type ReactNode } from 'react';

interface ErrorBoundaryProps {
  children: ReactNode;
  /** Custom fallback. Receives the error and a reset callback. */
  fallback?: (error: Error, reset: () => void) => ReactNode;
  /** Hook for reporting to monitoring (Sentry, Datadog, etc.). */
  onError?: (error: Error, info: ErrorInfo) => void;
}

interface ErrorBoundaryState {
  error: Error | null;
}

/**
 * Catches render-time errors in its subtree and shows a fallback UI.
 *
 * This MUST be a class component: React only exposes `getDerivedStateFromError`
 * and `componentDidCatch` to class components — there is no hook equivalent.
 * Place boundaries strategically (per-route and around risky widgets) rather
 * than only at the app root, so a single failure does not blank the whole app.
 */
export class ErrorBoundary extends Component<
  ErrorBoundaryProps,
  ErrorBoundaryState
> {
  state: ErrorBoundaryState = { error: null };

  static getDerivedStateFromError(error: Error): ErrorBoundaryState {
    return { error };
  }

  componentDidCatch(error: Error, info: ErrorInfo): void {
    this.props.onError?.(error, info);
    if (import.meta.env.DEV) {
      // eslint-disable-next-line no-console
      console.error('[ErrorBoundary] Caught error:', error, info);
    }
  }

  private readonly reset = (): void => {
    this.setState({ error: null });
  };

  render(): ReactNode {
    const { error } = this.state;
    const { children, fallback } = this.props;

    if (error !== null) {
      if (fallback) {
        return fallback(error, this.reset);
      }
      return (
        <div role="alert" className="error-boundary">
          <h2>Something went wrong</h2>
          <p>{error.message}</p>
          <button type="button" onClick={this.reset}>
            Try again
          </button>
        </div>
      );
    }

    return children;
  }
}
