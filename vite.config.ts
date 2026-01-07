import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

export default defineConfig({
  // Set base for GitHub Pages (project page) so asset URLs resolve correctly
  base: '/PractiCoreV5.1/',
  plugins: [react()],
  resolve: {
    alias: {
      '@': path.resolve(__dirname, './'),
    },
  },
  server: {
    port: 3000,
    host: true, // Listen on 0.0.0.0 (Required for accessing from Android Chrome)
    hmr: {
        // Ensures Hot Module Replacement works when accessed via IP
        clientPort: 3000 
    },
    watch: {
      // ESSENTIAL FOR TERMUX: Android FS doesn't always send change events. Polling fixes this.
      usePolling: true,
      interval: 100,
    }
  },
  preview: {
    port: 3000,
    host: true,
  },
  build: {
    outDir: 'dist',
    emptyOutDir: true,
    // Prevents warnings for large vendor chunks
    chunkSizeWarningLimit: 1600,
  }
});
