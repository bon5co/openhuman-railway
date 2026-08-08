#!/bin/sh
# Railway shim in front of upstream's docker-entrypoint-core.sh.
#
# openhuman-core reads its listen port from OPENHUMAN_CORE_PORT (baked to 7788)
# and ignores $PORT entirely. Railway injects PORT into every service, and its
# HTTP healthcheck dials that INJECTED port rather than the domain's target
# port -- so a service pinned to 7788 can serve 200 on its public URL for the
# whole window while the deploy fails with "1/1 replicas never became healthy".
# Following $PORT is what makes a healthcheck usable at all here.
#
# This shim only sets that variable and then hands over to upstream's
# entrypoint, which is where the real work happens: it heals the ownership of
# Railway's root-owned volume mount and drops privileges to the openhuman user
# with gosu. Replacing that script (which is what a Railway start command would
# do) skips all of it.
set -e

export OPENHUMAN_CORE_PORT="${PORT:-${OPENHUMAN_CORE_PORT:-7788}}"
export OPENHUMAN_CORE_HOST="${OPENHUMAN_CORE_HOST:-0.0.0.0}"
echo "[railway-entrypoint] OPENHUMAN_CORE_HOST=${OPENHUMAN_CORE_HOST} OPENHUMAN_CORE_PORT=${OPENHUMAN_CORE_PORT}"

exec /usr/local/bin/docker-entrypoint-core.sh "$@"
