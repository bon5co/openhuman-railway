# openhuman-railway

Railway-tuned wrapper image for [OpenHuman Core](https://github.com/tinyhumansai/openhuman) —
the Rust core (agent runtime, memory, skills, JSON-RPC) behind the OpenHuman desktop app,
run as an always-on remote backend.

Published as `ghcr.io/bon5co/openhuman-railway:latest`. Used by the Railway template
`scripts/specs/openhuman.json` in [railwaytemplate2](https://github.com/bon5co/railwaytemplate2).

## What this changes over `ghcr.io/tinyhumansai/openhuman-core`

| Change | Why |
| --- | --- |
| Managed Node runtime baked into the image | The agent harness downloads `node-v22.11.0-linux-x64.tar.xz` (29 MB, ~190 MB extracted) from nodejs.org on first boot, into `$XDG_CACHE_HOME` — which is not the workspace volume. On Railway every redeploy replays that download; with the runtime baked in, the first boot is already a warm start (`harness_init: warm start — all provisioning satisfied`) and needs no egress to nodejs.org. |
| `railway-entrypoint.sh` exports `OPENHUMAN_CORE_PORT="$PORT"` | The core reads `OPENHUMAN_CORE_PORT` and ignores `$PORT`. Railway's HTTP healthcheck dials the *injected* port, not the domain's target port, so a service pinned to 7788 cannot pass a healthcheck at all — measured: stock image with `PORT=8080` serves nothing on 8080. Following `$PORT` is what makes `healthcheckPath: /health` usable. |
| Image tag pinned to `0.63.7` | The core migrates its workspace (`config.toml`, SQLite session/memory DBs) forward on boot. An unpinned redeploy is an unrequested upgrade with no way back. |
| `BACKEND_URL` / `OPENHUMAN_WORKSPACE` baked as `ENV` | `templateGenerate` drops a template variable whose default is a literal and republishes it as a blank *required* field on the deploy form. Only deployer-owned values stay variables. |

## What this deliberately does not change

The upstream `ENTRYPOINT` (`docker-entrypoint-core.sh`) is kept and exec'd, not replaced. It
already heals the ownership of a root-owned volume mount and drops privileges to uid 10001 with
`gosu` — the Railway volume-permission fix, done upstream and done well. A Railway start command,
or an entrypoint that does not hand over to it, silently skips all of that.

Upstream also fails closed on auth: with no `OPENHUMAN_CORE_TOKEN`, the core refuses to bind a
non-loopback address rather than serving an open JSON-RPC surface (verified — the container exits
1). No wrapper-side auth is needed.
