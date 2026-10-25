<script lang="ts">
  import { PUBLIC_CONVEX_URL } from "$app/env/public";
  import { setupConvex } from "convex-svelte";
  import type { LayoutProps } from "./$types";

  let { children }: LayoutProps = $props();

  setupConvex(PUBLIC_CONVEX_URL);
</script>

{@render children()}
