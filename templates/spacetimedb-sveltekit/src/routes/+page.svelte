<script lang="ts">
  import { useReducer, useSpacetimeDB, useTable } from "spacetimedb/svelte";
  import { reducers, tables } from "../module_bindings";

  const conn = useSpacetimeDB();
  const [people] = useTable(tables.person);
  const add = useReducer(reducers.add);

  let name = $state("");

  function addPerson(e: SubmitEvent) {
    e.preventDefault();
    if (!name.trim()) return;
    add({ name });
    name = "";
  }
</script>

<h1>SpacetimeDB + SvelteKit</h1>

{#if $conn.connectionError}
  <p>Error: {$conn.connectionError.message}</p>
{:else if !$conn.isActive}
  <p>Connecting…</p>
{:else}
  <form onsubmit={addPerson}>
    <input placeholder="Name" aria-label="Name" bind:value={name} />
    <button type="submit">Add person</button>
  </form>

  <ul>
    {#each $people as person, i (i)}
      <li>{person.name}</li>
    {/each}
  </ul>
{/if}
