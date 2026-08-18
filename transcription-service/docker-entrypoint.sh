#!/bin/sh
# Fly mounts a fresh volume as root:root, but the relay runs as the unprivileged `node` user
# (RULES.md §3). Prepare the attested-key directory as root, then drop privileges for good before
# exec'ing the server — the Node process itself never runs as root.
set -e

DB_PATH="${APP_ATTEST_DB_PATH:-}"
if [ -n "$DB_PATH" ] && [ "$DB_PATH" != ":memory:" ]; then
  DB_DIR=$(dirname "$DB_PATH")
  mkdir -p "$DB_DIR"
  chown -R node:node "$DB_DIR"
fi

exec setpriv --reuid=node --regid=node --init-groups "$@"
