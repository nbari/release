#!/usr/bin/env bash
# Prove core tests do not build an application or use Docker/Node.
set -euo pipefail
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
for tool in cargo rustc node npm docker; do
  printf '#!/bin/sh\necho "Core framework invoked forbidden tool: %s" >&2\nexit 99\n' "$tool" > "$work/$tool"
  chmod +x "$work/$tool"
done
export PATH="$work:$PATH"
"$@"
