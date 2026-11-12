/** @type {import('jest').Config} */
module.exports = {
  preset: 'ts-jest',
  testEnvironment: 'node',
  testMatch: ['<rootDir>/test/**/*.spec.ts'],
  setupFiles: ['<rootDir>/test/env.ts'],
  collectCoverageFrom: ['src/**/*.ts', '!src/main.ts', '!src/seed.ts'],
  testTimeout: 30000,
};
