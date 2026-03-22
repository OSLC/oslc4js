import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

export default defineConfig({
  plugins: [react()],
  build: {
    outDir: '../public',
    emptyOutDir: true,
  },
  server: {
    proxy: {
      '/oslc': 'http://localhost:3005',
      '/resource': 'http://localhost:3005',
      '/compact': 'http://localhost:3005',
      '/sparql': 'http://localhost:3005',
      '/dialog': 'http://localhost:3005',
    },
  },
});
