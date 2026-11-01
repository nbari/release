#!/usr/bin/env bash
# release-flow-adapter: 1
# Release the framework's distribution bundle; no application toolchain.
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
command="${1:-}"
version="${2:-}"
valid_version() { [[ "$1" =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]]; }
case "$command" in
  version) cat VERSION ;;
  set-version)
    valid_version "$version" || exit 2
    printf '%s\n' "$version" > VERSION
    echo VERSION
    ;;
  verify)
    if [[ "${GITHUB_ACTIONS:-}" == true ]]; then
      bash "$root/tests/setup-ci.sh"
      export PATH="${RUNNER_TEMP}/release-metadata-tests/bin:${RUNNER_TEMP}/just-bin:$PATH"
    fi
    just check
    ;;
  targets) printf '[{"target":"any","runner":"ubuntu-24.04"}]\n' ;;
  inventory)
    valid_version "$version" || exit 2
    jq -n --arg n "release-flow-bundle-$version.tar.gz" --arg bash "$BASH_VERSION" \
      '{artifacts:[{name:$n,target:"any"}],build_info:{tools:{bash:$bash}}}'
    ;;
  package)
    [[ $# == 3 ]] && valid_version "$version" || { echo 'Usage: framework.sh package X.Y.Z OUTDIR' >&2; exit 2; }
    [[ "$(cat VERSION)" == "$version" ]] || { echo 'Version mismatch' >&2; exit 1; }
    [[ -z "${RELEASE_FLOW_TARGET:-}" || "$RELEASE_FLOW_TARGET" == any ]] || { echo 'Unknown framework target' >&2; exit 2; }
    out="$3"
    [[ ! -e "$out" || ( -d "$out" && -z "$(ls -A "$out")" ) ]] || { echo 'Output directory must be empty' >&2; exit 1; }
    bash "$root/scripts/release-flow-bundle.sh" --version "$version" --out "$out" --workflow-mode reusable >/dev/null
    ;;
  *) echo 'Expected version, set-version, verify, targets, inventory or package' >&2; exit 2 ;;
esac
