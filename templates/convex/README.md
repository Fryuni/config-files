# Convex + SvelteKit + Cloudflare Workers

A minimal Convex backend with TypeScript and ESLint, based on the official
[Convex bare template](https://github.com/get-convex/templates/tree/main/template-bare),
and a SvelteKit client built with `@sveltejs/adapter-cloudflare` for Cloudflare
Workers. Nix provides Node.js and pnpm.

## Develop

```sh
nix develop
pnpm install
pnpm dev
```

The first `pnpm dev` run prompts you to log in and create or select a Convex
deployment, generates `convex/_generated`, and writes `PUBLIC_CONVEX_URL` to
`.env.local`. It then runs the Convex dev server and the SvelteKit dev server
together. Edit `convex/myFunctions.ts` and `convex/schema.ts` to define your
backend and `src/routes` for the client. After generation, run `pnpm lint` to
typecheck and lint both with `svelte-check` and ESLint.

Set the Worker `name` in `wrangler.toml`. `pnpm preview` builds the client and
serves it with the local Workers runtime.

With the development server running, invoke the example from another shell:

```sh
pnpm exec convex run myFunctions:myQuery '{"first": 1, "second": "Hello"}'
```

## Forgejo Actions

Workflows run `pnpm lint` on each pull request and deploy on pushes to `main`
and for each pull request. `convex deploy --cmd "pnpm build"` deploys the backend
and builds the client with `PUBLIC_CONVEX_URL` pointing at that same deployment,
then Wrangler publishes the client:

- `main` deploys the production Convex backend and the Worker with
  `wrangler deploy`.
- Each pull request deploys a `pr-<number>` Convex preview backend and a
  `pr-<number>` [Worker Preview](https://developers.cloudflare.com/workers/previews/),
  served at `https://pr-<number>-<worker>.<subdomain>.workers.dev`. Previews do
  not inherit production `vars` or storage bindings; configure those under
  `previews` in `wrangler.toml`.
- Closing a pull request deletes both its Worker Preview and its Convex preview
  deployment, including the preview's data.

Configure these Forgejo repository secrets:

- `CONVEX_DEPLOY_KEY` — production deploy key used by the `main` deployment.
- `CONVEX_PREVIEW_DEPLOY_KEY` — preview deploy key used to generate types during
  PR tests and to create, update, and delete PR preview deployments.
- `CLOUDFLARE_API_TOKEN` — API token with the "Edit Cloudflare Workers"
  permissions, used by Wrangler to deploy production and previews.
- `CLOUDFLARE_ACCOUNT_ID` — Cloudflare account that owns the Worker.

See the [Convex](https://docs.convex.dev/home),
[SvelteKit](https://svelte.dev/docs/kit), and
[Worker Previews](https://developers.cloudflare.com/workers/previews/)
documentation for more.
