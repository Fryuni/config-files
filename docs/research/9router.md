# 9Router in front of CLIProxyAPI

Researched: 2026-09-21. Primary-source inspection of upstream
[`decolua/9router` at `a8c9d380`](https://github.com/decolua/9router/tree/a8c9d3802c5933500fba95416f5bf0c130581396).
This describes that source revision, not necessarily the friend's installed release.
No live provider calls or performance benchmarks were run. Recommendations and
operational consequences below are identified as assessments.

## Answer: virtual models support both fallback and rotation

9Router calls these **combos**. Each has a client-visible name and a list of
underlying models. `/v1/models` advertises the combo as a model, so a client can
request `coding` while its membership changes centrally. The current dashboard
offers three strategies. [Model catalog](https://github.com/decolua/9router/blob/a8c9d3802c5933500fba95416f5bf0c130581396/src/app/api/v1/models/route.js#L303-L317),
[dashboard options](https://github.com/decolua/9router/blob/a8c9d3802c5933500fba95416f5bf0c130581396/src/app/%28dashboard%29/dashboard/combos/page.js#L291-L295).

| Strategy | Example with models A, B, C | Meaning |
| --- | --- | --- |
| Fallback, the default | Every request tries A; eligible failure leads to B, then C. | Ordered preference with backups. |
| Round-robin | First request tries A→B→C; next B→C→A; next C→A→B. | Rotates the preferred model and retains fallback. |
| Fusion | Calls several panel models concurrently, then asks a judge model to produce the final response. | Multiple-model generation, with additional usage and latency. |

These are verified in the [routing implementation](https://github.com/decolua/9router/blob/a8c9d3802c5933500fba95416f5bf0c130581396/open-sse/services/combo.js)
and [settings defaults](https://github.com/decolua/9router/blob/a8c9d3802c5933500fba95416f5bf0c130581396/src/lib/db/repos/settingsRepo.js#L7-L24).
Fusion removes tools from panel requests; the final judge receives the original
request plus panel answers. It is not ordinary load balancing.

Round-robin has a configurable request-count stickiness, default one request per
starting model. Its state is an in-memory map keyed by combo name, not conversation
ID. The pointer advances before the attempt succeeds. Consequently, successful
traffic need not split evenly if some models fail; restarting a process resets
rotation. This is request rotation, not weighted, latency-aware or least-loaded
scheduling. [Rotation code](https://github.com/decolua/9router/blob/a8c9d3802c5933500fba95416f5bf0c130581396/open-sse/services/combo.js#L201-L248).

Two qualifications matter:

- Capability detection can move suitable image/PDF/audio/video models ahead of the
  nominal order. Configured capacity adapters can add models too. This is modality
  matching, not a model judging which backend best answers a difficult prompt.
  [Capability sorting](https://github.com/decolua/9router/blob/a8c9d3802c5933500fba95416f5bf0c130581396/open-sse/services/combo.js#L61-L81),
  [chat dispatch](https://github.com/decolua/9router/blob/a8c9d3802c5933500fba95416f5bf0c130581396/src/sse/handlers/chat.js#L92-L138).
- Failover depends on error classification. Rate limits, account errors and server
  errors can trigger it; ordinary malformed-request/context-overflow errors need
  not. The combo returns immediately on a successful HTTP response, so it does not
  guarantee seamless recovery after a streaming response has begun.
  [Error classifier](https://github.com/decolua/9router/blob/a8c9d3802c5933500fba95416f5bf0c130581396/open-sse/services/accountFallback.js#L22-L63),
  [attempt loop](https://github.com/decolua/9router/blob/a8c9d3802c5933500fba95416f5bf0c130581396/open-sse/services/combo.js#L280-L365).

## What it adds in front of CLIProxyAPI

The plausible topology is `client → 9Router → CLIProxyAPI → providers`.
9Router accepts custom OpenAI-compatible providers with a base URL and either
Chat Completions or Responses API mode. Therefore CLIProxyAPI can be configured
as an upstream, and its exposed models can become combo members. This is an
integration inference from the compatible-provider interface, not verification
of the friend's particular setup. [Provider-node API](https://github.com/decolua/9router/blob/a8c9d3802c5933500fba95416f5bf0c130581396/src/app/api/provider-nodes/route.js#L32-L70).

**Important overlap:** CLIProxyAPI already supports model aliases and account
routing. Its current configuration example also explicitly permits repeated
aliases under `openai-compatibility` to create a pool of different upstream model
names, rotating among them and trying the next before output on failure.
Simple virtual model pools alone therefore do not establish a need for 9Router.
That specific pool feature should not be assumed to be a universal ordered chain
across every native OAuth provider. [CLIProxyAPI configuration example, inspected at `a5ab6952`](https://github.com/router-for-me/CLIProxyAPI/blob/a5ab69521f7b4e0f244836d0419da8fcd89408ea/config.example.yaml#L777-L787).

The more distinctive benefit is a UI for named, ordered chains across providers,
plus additional request processing. Account selection inside CLIProxyAPI remains
a separate layer from 9Router's choice of model.

## Pros

- **Central routing profiles:** keep stable names such as `coding-quality` and
  `coding-budget`, edit membership and strategy once, and use them across clients.
  This follows directly from the combo catalog and routing implementation above.
- **Ordered cost/quality preferences:** choose subscription-backed models first,
  then explicitly chosen paid or alternative providers. Assessment: useful when
  preference order matters more than spreading requests evenly.
- **Operational UI:** provider management, quota views, usage estimates and request
  diagnostics are advertised together. Assessment: this can make a mixed-provider
  setup easier to manage. Dashboard dollar figures are estimates, not necessarily
  bills. [First-party feature descriptions](https://github.com/decolua/9router/blob/a8c9d3802c5933500fba95416f5bf0c130581396/README.md#L608-L680).
- **Optional transformations:** RTK compresses tool output; other options add
  terseness/minimal-code instructions or external compression. Assessment: these
  may reduce usage on repetitive workflows, but savings need workload-specific
  measurement. [RTK implementation](https://github.com/decolua/9router/tree/a8c9d3802c5933500fba95416f5bf0c130581396/open-sse/rtk).

## Cons and practical limits

- **Another stateful service:** a Next.js/Node application with SQLite is added to
  the request path. Assessment: this adds updates, backups, failure modes and
  latency; retries in both proxies can compound slow failures. No measured latency
  claim is made. If all combo members use the same CLIProxyAPI instance, its outage
  still takes down the entire combo. [Dependencies](https://github.com/decolua/9router/blob/a8c9d3802c5933500fba95416f5bf0c130581396/package.json),
  [database location](https://github.com/decolua/9router/blob/a8c9d3802c5933500fba95416f5bf0c130581396/README.md#L1314-L1318).
- **Model identity and behavior can change between turns.** Assessment: fallback
  or rotation can alter reasoning quality, context limits, tool behavior, caching
  and cost. A common API format does not make backends behaviorally identical.
- **An extra translation layer can weaken features.** The default executor changes
  `json_schema` structured output into `json_object` plus a schema instruction for
  custom OpenAI-compatible providers. Assessment: do not assume native strict
  schema enforcement survives this extra hop even if CLIProxyAPI supports it.
  [Schema fallback](https://github.com/decolua/9router/blob/a8c9d3802c5933500fba95416f5bf0c130581396/open-sse/executors/default.js#L84-L102).
- **Compression can remove information.** Despite README “lossless” wording, the
  smart-truncate filter discards middle lines and the diff filter truncates hunks.
  RTK is enabled by default. Assessment: turn it off for a baseline before judging
  quality or savings. [Truncation](https://github.com/decolua/9router/blob/a8c9d3802c5933500fba95416f5bf0c130581396/open-sse/rtk/filters/smartTruncate.js),
  [diff filter](https://github.com/decolua/9router/blob/a8c9d3802c5933500fba95416f5bf0c130581396/open-sse/rtk/filters/gitDiff.js),
  [defaults](https://github.com/decolua/9router/blob/a8c9d3802c5933500fba95416f5bf0c130581396/src/lib/db/repos/settingsRepo.js#L48-L64).
- **Observability has limits through another proxy.** Assessment: 9Router can see
  the upstream model/API result, but should not be assumed to know which underlying
  CLIProxyAPI account served it or that account's true quota. Request diagnostics
  also introduce another place where prompt data can be retained; detailed
  observability and cloud sync are disabled in the inspected defaults.
  [Defaults](https://github.com/decolua/9router/blob/a8c9d3802c5933500fba95416f5bf0c130581396/src/lib/db/repos/settingsRepo.js#L7-L45).
- **Version and documentation drift:** the GitBook describes ordered fallback,
  while current code includes rotation and Fusion. Check the installed version
  rather than assuming every current-source feature exists there.
  [GitBook combo guide](https://github.com/decolua/9router/blob/a8c9d3802c5933500fba95416f5bf0c130581396/gitbook/content/en/features/combos.md).

## Assessment

For the stated interest, first check whether the installed CLIProxyAPI's alias
pools satisfy the need. Add 9Router when the UI and explicit ordered model chains
are useful enough to justify another service. A sensible trial is one fallback
combo with two compatible coding models and token savers disabled; verify actual
model selection, failure handling and tool calls before expanding it. Prefer
round-robin when deliberately sharing traffic is the goal, and fallback when one
model should remain preferred.
