import { defineConfig, globalIgnores } from "eslint/config";

import globals from "globals";
import tsParser from "@typescript-eslint/parser";
import js from "@eslint/js";
import convexPlugin from "@convex-dev/eslint-plugin";
import svelte from "eslint-plugin-svelte";

import { FlatCompat } from "@eslint/eslintrc";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
const compat = new FlatCompat({
  baseDirectory: __dirname,
  recommendedConfig: js.configs.recommended,
  allConfig: js.configs.all,
});

export default defineConfig([
  {
    files: ["convex/**/*.ts"],
    languageOptions: {
      globals: {
        ...globals.browser,
        ...globals.node,
      },

      parser: tsParser,

      parserOptions: {
        project: join(__dirname, "convex", "tsconfig.json"),
      },
    },

    extends: compat.extends(
      "eslint:recommended",
      "plugin:@typescript-eslint/recommended-type-checked",
    ),

    rules: {
      "@typescript-eslint/no-unused-vars": [
        "warn",
        {
          varsIgnorePattern: "^_",
          argsIgnorePattern: "^_",
        },
      ],

      "@typescript-eslint/ban-ts-comment": "error",
      "@typescript-eslint/no-explicit-any": "off",
      "@typescript-eslint/no-unsafe-argument": "off",
      "@typescript-eslint/no-unsafe-assignment": "off",
      "@typescript-eslint/no-unsafe-call": "off",
      "@typescript-eslint/no-unsafe-member-access": "off",
      "@typescript-eslint/no-unsafe-return": "off",
      "@typescript-eslint/require-await": "off",
    },
  },
  {
    files: ["src/**/*.ts", "src/**/*.svelte"],
    languageOptions: { globals: globals.browser },
    extends: compat.extends(
      "eslint:recommended",
      "plugin:@typescript-eslint/recommended",
    ),
  },
  // After the TypeScript config so `.svelte` files keep the Svelte parser.
  ...svelte.configs.recommended,
  {
    files: ["src/**/*.svelte"],
    languageOptions: { parserOptions: { parser: tsParser } },
  },
  globalIgnores(["convex/_generated", ".svelte-kit", ".wrangler"]),
  ...convexPlugin.configs.recommended,
]);
