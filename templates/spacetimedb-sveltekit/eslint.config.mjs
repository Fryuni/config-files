import { defineConfig, globalIgnores } from "eslint/config";

import globals from "globals";
import js from "@eslint/js";
import tsPlugin from "@typescript-eslint/eslint-plugin";
import tsParser from "@typescript-eslint/parser";
import svelte from "eslint-plugin-svelte";

export default defineConfig([
  js.configs.recommended,
  ...tsPlugin.configs["flat/recommended"],
  ...tsPlugin.configs["flat/recommended-type-checked"].map((config) => ({
    ...config,
    files: ["spacetimedb/src/**/*.ts"],
  })),
  {
    files: ["spacetimedb/src/**/*.ts"],
    languageOptions: {
      parserOptions: {
        project: "./spacetimedb/tsconfig.json",
        tsconfigRootDir: import.meta.dirname,
      },
    },
  },
  {
    rules: {
      "@typescript-eslint/no-unused-vars": [
        "warn",
        {
          varsIgnorePattern: "^_",
          argsIgnorePattern: "^_",
        },
      ],
    },
  },
  // After the TypeScript config so `.svelte` files keep the Svelte parser.
  ...svelte.configs.recommended,
  {
    files: ["src/**/*.svelte"],
    languageOptions: { parserOptions: { parser: tsParser } },
  },
  {
    files: ["src/**/*.ts", "src/**/*.svelte"],
    languageOptions: { globals: globals.browser },
  },
  globalIgnores([
    "src/module_bindings",
    "spacetimedb/dist",
    ".svelte-kit",
    ".wrangler",
  ]),
]);
