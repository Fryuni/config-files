# SpacetimeDB + Rust

A minimal SpacetimeDB module based on the official
[`basic-rs` template](https://github.com/clockworklabs/SpacetimeDB/tree/master/templates/basic-rs).
Nix provides the SpacetimeDB CLI and a Rust toolchain with the WebAssembly target.

## Develop

```sh
nix develop
spacetime dev
```

This starts a local SpacetimeDB server and publishes the module. Edit
`src/lib.rs` to change the example `Person` table and its reducers.

Check the module without starting the server:

```sh
cargo check --target wasm32-unknown-unknown
```

With the development server running, try it from another shell:

```sh
spacetime call add Alice
spacetime sql "SELECT * FROM person"
spacetime call say_hello
```

## Forgejo Actions

Workflows check the Rust module on each pull request and publish it on pushes to
`main`. Configure these Forgejo repository secrets:

- `SPACETIMEDB_TOKEN` — CLI login token with permission to publish the database.
- `SPACETIMEDB_HOST` — URL or nickname of the target SpacetimeDB server.
- `SPACETIMEDB_DATABASE` — name or identity of the database to create or update.

Deployment does not automatically approve data deletion or breaking client
changes; a push requiring either fails for manual review.

See the [SpacetimeDB Rust documentation](https://spacetimedb.com/docs/modules/rust)
for more.
