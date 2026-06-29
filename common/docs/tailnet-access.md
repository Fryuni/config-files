# Tailnet Access Agent Prompt

Implement a private URL layer for the user's tailnet or equivalent private network. Assume you are running on a machine that can reach and administer the other machines in the network.

Use these placeholders until you discover or ask for the real values:

- `device`: a target machine name.
- `<private-domain>`: the private URL suffix to create.
- `<tailnet-domain>`: the existing tailnet DNS suffix where `device.<tailnet-domain>` already resolves.

Build this behavior for each target machine using a static Caddy configuration:

1. `device.<private-domain>` opens a tiny landing page documenting the URL patterns.
2. `<port>.device.<private-domain>` proxies to the HTTP service listening on that port on the same machine.
3. `<port>-local.device.<private-domain>` proxies to the same port, but sends localhost-style Host and Origin values upstream for tools that expect `localhost:<port>`.
4. **Bind the Caddy listener exclusively to the private network interface.**

Add private DNS for `<private-domain>`:

1. Run or configure a simple DNS server reachable by trusted network clients.
2. Resolve both `device.<private-domain>` and `*.device.<private-domain>` to a CNAME for `device.<tailnet-domain>`.
3. Keep this DNS private to the tailnet or trusted network.

Add private HTTPS:

1. Create a private CA for this hostname space.
2. Keep the CA private key protected and use it only for this private URL layer.
3. Provide the CA public certificate so trusted client devices can install or trust it.
4. For each machine, emit a certificate and private key covering these SANs:
   - `device.<private-domain>`
   - `*.device.<private-domain>`
5. Configure the machine's HTTP/HTTPS entrypoint to use that certificate for the base and wildcard names.

Keep the system private. Do not expose these services to the public internet, and do not make the design depend on a specific operating system, package manager, DNS server, reverse proxy, or certificate tool unless the user's environment already requires one.

Verify from another trusted machine when possible:

- `device.<private-domain>` opens the landing page.
- `<port>.device.<private-domain>` reaches a service on that port.
- `<port>-local.device.<private-domain>` works for localhost-sensitive services.
- DNS returns `device.<tailnet-domain>` as the CNAME target for the base and wildcard private names.
- HTTPS works without browser certificate warnings after the CA is trusted.
