/**
 * ENVI Cloud Functions — ESLint configuration.
 *
 * Matches the strict TypeScript mode enforced in tsconfig.json so lint errors
 * surface before compilation. Kept intentionally small; we only need enough to
 * catch obvious pitfalls in a TS-strict Firebase Functions 2nd gen codebase.
 */
module.exports = {
  root: true,
  env: {
    es2022: true,
    node: true,
  },
  extends: [
    "eslint:recommended",
    "plugin:@typescript-eslint/recommended",
  ],
  parser: "@typescript-eslint/parser",
  parserOptions: {
    ecmaVersion: 2022,
    sourceType: "module",
    project: ["tsconfig.json"],
    tsconfigRootDir: __dirname,
  },
  plugins: ["@typescript-eslint"],
  ignorePatterns: ["lib/**/*", "node_modules/**/*", "coverage/**/*", ".eslintrc.js"],
  rules: {
    quotes: ["error", "double", { avoidEscape: true }],
    "@typescript-eslint/no-unused-vars": ["error", { argsIgnorePattern: "^_" }],
    "@typescript-eslint/no-explicit-any": "warn",
  },
};
