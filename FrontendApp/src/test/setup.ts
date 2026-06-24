import '@testing-library/jest-dom/vitest';
import { cleanup } from '@testing-library/react';
import { afterEach, vi } from 'vitest';

// jsdom does not implement matchMedia, which MUI (useMediaQuery) and our theme
// initialization rely on. Provide a minimal, non-matching stub.
if (!window.matchMedia) {
  window.matchMedia = vi.fn().mockImplementation((query: string) => ({
    matches: false,
    media: query,
    onchange: null,
    addEventListener: vi.fn(),
    removeEventListener: vi.fn(),
    addListener: vi.fn(),
    removeListener: vi.fn(),
    dispatchEvent: vi.fn(),
  }));
}

// React Testing Library does not auto-cleanup with Vitest's `globals`
// in every config, so we unmount the DOM between tests explicitly to
// prevent state leaking across test cases.
afterEach(() => {
  cleanup();
});
