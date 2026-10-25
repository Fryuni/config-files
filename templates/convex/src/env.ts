import { defineEnvVars } from "@sveltejs/kit/env";

export const variables = defineEnvVars({
  PUBLIC_CONVEX_URL: {
    public: true,
    // Inlined at build time: `convex dev` writes it to `.env.local` and
    // `convex deploy --cmd` sets it for the matching deployment in CI.
    static: true,
    description: "URL of the Convex deployment the client talks to.",
  },
});
