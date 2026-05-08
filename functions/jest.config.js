/**
 * Jest configuration for ENVI Cloud Functions.
 *
 * ts-jest runs the TypeScript source directly so the __tests__ folder doesn't
 * get copied into lib/ at build time. The `isolatedModules` flag avoids a full
 * type-check on every test run — `npm run build` remains the authoritative
 * type-check gate.
 */
module.exports = {
  preset: "ts-jest",
  testEnvironment: "node",
  setupFiles: ["<rootDir>/jest.env.js"],
  roots: ["<rootDir>/src"],
  testMatch: ["**/__tests__/**/*.test.ts"],
  moduleFileExtensions: ["ts", "js", "json"],
  transform: {
    "^.+\\.ts$": ["ts-jest", { isolatedModules: true }],
  },
  collectCoverageFrom: [
    "src/**/*.ts",
    "!src/__tests__/**",
    "!src/index.ts",
  ],
  coverageDirectory: "coverage",
  clearMocks: true,
  restoreMocks: true,
};
