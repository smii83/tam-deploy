import { defineConfig } from 'vitest/config';
import path from 'node:path';

export default defineConfig({
  resolve: {
    alias: {
      'firebase-admin': path.resolve(__dirname, 'functions/node_modules/firebase-admin'),
      'firebase-functions/v2/https': path.resolve(
        __dirname,
        'functions/node_modules/firebase-functions/lib/v2/providers/https'
      ),
    },
  },
  test: {
    environment: 'node',
    include: ['tests/unit/**/*.test.ts'],
    globals: true,
    coverage: {
      provider: 'v8',
      include: ['functions/src/logic.ts', 'admin_dashboard/helpers.js'],
    },
  },
});
