<script lang="ts">
  import { useQuery } from "convex-svelte";
  import { api } from "../../convex/_generated/api";

  const result = useQuery(api.myFunctions.myQuery, {
    first: 1,
    second: "Hello",
  });
</script>

<h1>Convex + SvelteKit</h1>

{#if result.isLoading}
  <p>Loading…</p>
{:else if result.error}
  <p>Error: {result.error.message}</p>
{:else}
  <p>myQuery returned {result.data}</p>
{/if}
