/// <reference types="vitest/config" />
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import { fileURLToPath, URL } from 'node:url';

// https://vite.dev/config/
export default defineConfig({
  plugins: [react()],
  resolve: {
    alias: {
      '@': fileURLToPath(new URL('./src', import.meta.url)),
    },
  },
  server: {
    port: 3000,
    strictPort: false,
  },
  build: {
    target: 'es2023',
    sourcemap: true,
    rollupOptions: {
      output: {
        // Split heavy, rarely-changing vendor code into its own chunk for
        // better long-term browser caching.
        manualChunks(id) {
          if (id.includes('node_modules')) {
            if (
              id.includes('react-router') ||
              id.includes('/react/') ||
              id.includes('/react-dom/')
            ) {
              return 'react-vendor';
            }
          }
          return undefined;
        },
      },
    },
  },
  test: {
    globals: true,
    environment: 'jsdom',
    setupFiles: ['./src/test/setup.ts'],
    css: true,
    coverage: {
      provider: 'v8',
      reporter: ['text', 'html'],
      exclude: [
        '**/node_modules/**',
        '**/test/**',
        '**/*.config.*',
        '**/main.tsx',
        '**/*.d.ts',
      ],
    },
  },
});
