<script lang="ts">
  import {
    PUBLIC_SPACETIMEDB_DB_NAME,
    PUBLIC_SPACETIMEDB_HOST,
  } from "$app/env/public";
  import { createSpacetimeDBProvider } from "spacetimedb/svelte";
  import { DbConnection } from "../module_bindings";
  import type { LayoutProps } from "./$types";

  let { children }: LayoutProps = $props();

  const tokenKey = `${PUBLIC_SPACETIMEDB_HOST}/${PUBLIC_SPACETIMEDB_DB_NAME}/auth_token`;

  createSpacetimeDBProvider(
    DbConnection.builder()
      .withUri(PUBLIC_SPACETIMEDB_HOST)
      .withDatabaseName(PUBLIC_SPACETIMEDB_DB_NAME)
      .withToken(localStorage.getItem(tokenKey) ?? undefined)
      .onConnect((_conn, _identity, token) =>
        localStorage.setItem(tokenKey, token),
      ),
  );
</script>

{@render children()}
