#!/usr/bin/env bash
# Framework development tools only; never used by the composite Action.
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
: "${RUNNER_TEMP:?CI runner temporary directory required}"
bash "$root/tests/pipeline/ci-install-just.sh"
python3 -m venv "${RUNNER_TEMP}/release-metadata-tests"
"${RUNNER_TEMP}/release-metadata-tests/bin/python" -m pip install --disable-pip-version-check -r "$root/tests/requirements.txt"
if [[ -n "${GITHUB_PATH:-}" ]]; then
  printf '%s\n' "${RUNNER_TEMP}/release-metadata-tests/bin" >> "$GITHUB_PATH"
fi
