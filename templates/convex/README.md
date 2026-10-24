# Convex + TypeScript + pnpm

A minimal Convex backend with TypeScript and ESLint, based on the official
[Convex bare template](https://github.com/get-convex/templates/tree/main/template-bare).
Nix provides Node.js and pnpm.

## Develop

```sh
nix develop
pnpm install
pnpm dev
```

The first `pnpm dev` run prompts you to log in and create or select a Convex
deployment, then generates `convex/_generated`. Edit `convex/myFunctions.ts` and
`convex/schema.ts` to define your backend. After generation, run `pnpm lint` to
typecheck and lint it.

With the development server running, invoke the example from another shell:

```sh
pnpm exec convex run myFunctions:myQuery '{"first": 1, "second": "Hello"}'
```

## Forgejo Actions

Workflows typecheck and lint each pull request, deploy the production backend on
pushes to `main`, and maintain a `pr-<number>` preview backend for each pull
request. Preview and production workflows deploy only Convex; they do not build
or deploy a client.

Configure these Forgejo repository secrets:

- `CONVEX_DEPLOY_KEY` — production deploy key used by the `main` deployment.
- `CONVEX_PREVIEW_DEPLOY_KEY` — preview deploy key used to generate types during
  PR tests and to create or update PR preview deployments.

See the [Convex documentation](https://docs.convex.dev/home) for more.
