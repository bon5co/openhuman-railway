# Railway-tuned OpenHuman Core.
#
# Two changes over the upstream image, both aimed at Railway's redeploy model:
#
#  1. The managed Node runtime is baked in. OpenHuman's agent harness downloads
#     node-v22.11.0-linux-x64.tar.xz (29 MB) from nodejs.org on first boot and
#     installs it under $XDG_CACHE_HOME (default /home/openhuman/.cache), which
#     is NOT the workspace volume. On Railway every redeploy starts from the
#     image layer, so that download and its ~190 MB of extracted output are paid
#     again on every deploy, and a boot with no egress to nodejs.org leaves the
#     JS harness unavailable. Baking it into the image makes the very first boot
#     a warm start.
#  2. The tag is pinned. Upstream ships frequently and the core migrates its
#     workspace (config.toml, SQLite session/memory databases) forward on boot,
#     so an unpinned redeploy is an unrequested upgrade with no way back.
#
# Deliberately NOT changed: the upstream ENTRYPOINT. docker-entrypoint-core.sh
# already heals the ownership of a root-owned mount and then drops privileges to
# uid 10001 with gosu, which is exactly the Railway volume fix this repo usually
# has to add by hand. A start command would REPLACE it and silently skip all of
# that.
ARG NODE_VERSION=v22.11.0

FROM debian:bookworm-slim AS node-runtime
ARG NODE_VERSION
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends ca-certificates curl xz-utils; \
    rm -rf /var/lib/apt/lists/*; \
    cd /tmp; \
    curl -fsSLO "https://nodejs.org/dist/${NODE_VERSION}/node-${NODE_VERSION}-linux-x64.tar.xz"; \
    curl -fsSLO "https://nodejs.org/dist/${NODE_VERSION}/SHASUMS256.txt"; \
    grep " node-${NODE_VERSION}-linux-x64.tar.xz\$" SHASUMS256.txt | sha256sum -c -; \
    mkdir -p /out; \
    tar -xJf "node-${NODE_VERSION}-linux-x64.tar.xz" -C /out; \
    /out/"node-${NODE_VERSION}-linux-x64"/bin/node --version

FROM ghcr.io/tinyhumansai/openhuman-core:0.63.7
ARG NODE_VERSION

# uid/gid 10001 is the `openhuman` user the upstream entrypoint drops to; the
# cache is read by that user, not by root.
COPY --from=node-runtime --chown=10001:10001 /out/node-${NODE_VERSION}-linux-x64 \
     /home/openhuman/.cache/openhuman/node-runtime/node-${NODE_VERSION}-linux-x64

# Baked, NOT published as template variables: templateGenerate drops a variable
# whose default is a literal and republishes it as a blank REQUIRED field on the
# deploy form. Only values that genuinely belong to the deployer stay variables,
# and those are Railway expressions (${{secret(n)}}, ${{RAILWAY_PUBLIC_DOMAIN}}).
#
# OPENHUMAN_CORE_PORT is left at the image's 7788 and Railway's injected PORT is
# ignored: the core reads OPENHUMAN_CORE_PORT only, and the template's domain
# targets 7788 explicitly.
ENV BACKEND_URL=https://api.tinyhumans.ai \
    OPENHUMAN_WORKSPACE=/home/openhuman/.openhuman

COPY railway-entrypoint.sh /usr/local/bin/railway-entrypoint.sh
RUN chmod +x /usr/local/bin/railway-entrypoint.sh
ENTRYPOINT ["/usr/local/bin/railway-entrypoint.sh"]
CMD ["serve"]
