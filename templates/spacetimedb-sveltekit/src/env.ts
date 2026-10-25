import { defineEnvVars } from "@sveltejs/kit/env";

// Inlined at build time: `spacetime dev` writes both to `.env.local` and CI
// sets them for the database it publishes.
export const variables = defineEnvVars({
  PUBLIC_SPACETIMEDB_HOST: {
    public: true,
    static: true,
    description: "URL of the SpacetimeDB server the client talks to.",
  },
  PUBLIC_SPACETIMEDB_DB_NAME: {
    public: true,
    static: true,
    description: "Name of the SpacetimeDB database the client talks to.",
  },
});
