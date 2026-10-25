# SpacetimeDB + SvelteKit + Cloudflare Workers

A SpacetimeDB TypeScript module and a SvelteKit client in one pnpm workspace,
based on the official
[`svelte-ts` template](https://github.com/clockworklabs/SpacetimeDB/tree/master/templates/svelte-ts).
The module lives in the `spacetimedb` package; the client at the root is built
with `@sveltejs/adapter-cloudflare` for Cloudflare Workers. Nix provides
Node.js, pnpm, and the SpacetimeDB CLI.

## Develop

```sh
nix develop
pnpm install
spacetime start   # in another shell, for a local server
spacetime dev --server local
```

`spacetime dev` publishes the module, regenerates the client bindings in
`src/module_bindings`, writes `PUBLIC_SPACETIMEDB_HOST` and
`PUBLIC_SPACETIMEDB_DB_NAME` to `.env.local`, and runs the SvelteKit dev server,
republishing whenever the module changes. The chosen database is saved to
`spacetime.local.json`. Edit `spacetimedb/src/index.ts` to change the example
`person` table and its reducers, and `src/routes` for the client. Use
`--server maincloud` to develop against Maincloud instead.

Run `pnpm generate` to regenerate bindings without a server, then `pnpm lint`
to typecheck and lint the module and client with `tsc`, `svelte-check`, and
ESLint. The client renders in the browser only (`ssr = false`), since its
SpacetimeDB connection is a WebSocket authenticated by a token in
`localStorage`.

Set the Worker `name` in `wrangler.toml`. `pnpm preview` builds the client and
serves it with the local Workers runtime.

With the development server running, try the module from another shell:

```sh
spacetime call --server local add Alice
spacetime sql --server local "SELECT * FROM person"
spacetime call --server local say_hello
```

## Forgejo Actions

Workflows run `pnpm lint` on each pull request and deploy on pushes to `main`
and for each pull request. Each deployment publishes the module, then builds
the client with `PUBLIC_SPACETIMEDB_HOST` and `PUBLIC_SPACETIMEDB_DB_NAME`
pointing at that same database, and Wrangler publishes the client:

- `main` publishes to the production database and deploys the Worker with
  `wrangler deploy`. It does not automatically approve data deletion or
  breaking client changes; a push requiring either fails for manual review.
- Each pull request publishes to a `<database>-pr-<number>` database and
  deploys a `pr-<number>`
  [Worker Preview](https://developers.cloudflare.com/workers/previews/), served
  at `https://pr-<number>-<worker>.<subdomain>.workers.dev`. Preview databases
  are cleared when a schema change conflicts with their data. Worker Previews
  do not inherit production `vars` or storage bindings; configure those under
  `previews` in `wrangler.toml`.
- Closing a pull request deletes both its Worker Preview and its preview
  database, including the preview's data.

Configure these Forgejo repository secrets:

- `SPACETIMEDB_TOKEN` — CLI login token with permission to publish and delete
  the production and preview databases.
- `SPACETIMEDB_HOST` — URL of the SpacetimeDB server, such as
  `https://maincloud.spacetimedb.com`; the client connects to it too.
- `SPACETIMEDB_DATABASE` — name of the production database, also the prefix of
  preview database names.
- `CLOUDFLARE_API_TOKEN` — API token with the "Edit Cloudflare Workers"
  permissions, used by Wrangler to deploy production and previews.
- `CLOUDFLARE_ACCOUNT_ID` — Cloudflare account that owns the Worker.

See the [SpacetimeDB TypeScript](https://spacetimedb.com/docs/clients/typescript),
[SvelteKit](https://svelte.dev/docs/kit), and
[Worker Previews](https://developers.cloudflare.com/workers/previews/)
documentation for more.
