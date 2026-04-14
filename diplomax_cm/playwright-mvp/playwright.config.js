// Playwright MVP for backend API validation
const { defineConfig } = require('@playwright/test');

module.exports = defineConfig({
  testDir: './tests',
  timeout: 30_000,
  fullyParallel: false,
  reporter: [['list'], ['html', { open: 'never' }]],
  use: {
    baseURL: process.env.API_BASE_URL || 'https://diplomax-backend.onrender.com',
    extraHTTPHeaders: {
      Accept: 'application/json',
    },
  },
});
