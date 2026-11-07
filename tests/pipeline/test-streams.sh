#!/usr/bin/env bash
# Large-input regressions for pipefail-safe release readers and guards. Exercise
# production entrypoints: successful reads must drain their input, and a match
# must never disappear because an upstream writer receives SIGPIPE.
set -euo pipefail
# shellcheck source=tests/pipeline/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
# shellcheck source=tests/pipeline/lib-release.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib-release.sh"

tf_forbid_toolchains
tf_mock_gh_on
REAL_GIT="$(command -v git)"

# Run a production command in a fixture without changing the suite's directory.
# shellcheck disable=SC2317,SC2329 # Called indirectly by t_run.
in_repo() {
  local repo="$1"
  shift
  (cd "${repo}" && "$@")
}

# Compare all observable local and remote Git state without printing huge lists.
git_state() {
  tf_snapshot "$1"
  tf_remote_refs "$2"
}

# A separate strict shell keeps test harness error handling from masking pipefail.
# shellcheck disable=SC2317,SC2329 # Called indirectly by t_run.
lookup() {
  bash -euo pipefail -c '
    source "$1/scripts/lib/common.sh"
    refs="$(cat "$2")"
    rf_ls_remote_value "$refs" "$3"
  ' -- "${ROOT}" "$1" "$2"
}

t_case 'ST01: Exact remote-ref lookup drains large input and preserves first match'
refs="${TF_TMP}/refs"
awk 'BEGIN {
  for (i=0; i<10000; i++) printf "%040d\trefs/heads/branch-%05d\n", i, i
  print "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\trefs/heads/branch-00000"
  print "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb\trefs/tags/1.2.3"
  print "cccccccccccccccccccccccccccccccccccccccc\trefs/tags/1.2.3^{}"
}' > "${refs}"
for row in 0 5000 9999; do
  printf -v ref 'refs/heads/branch-%05d' "${row}"
  printf -v sha '%040d' "${row}"
  t_run lookup "${refs}" "${ref}"
  assert_rc 0 "ST01: lookup row ${row} succeeds"
  assert_eq "${sha}" "${T_OUT}" "ST01: exact SHA at row ${row}"
done
for ref in refs/heads/branch-0 refs/heads/missing ''; do
  t_run lookup "${refs}" "${ref}"
  assert_rc 0 'ST01: missing ref succeeds with no value'
  assert_eq '' "${T_OUT}" 'ST01: no partial or empty-ref match'
done
t_run lookup "${refs}" 'refs/tags/1.2.3^{}'
assert_rc 0 'ST01: peeled ref succeeds'
assert_eq cccccccccccccccccccccccccccccccccccccccc "${T_OUT}" 'ST01: peeled ref is distinct from tag object'
: > "${TF_TMP}/empty"
t_run lookup "${TF_TMP}/empty" refs/heads/missing
assert_rc 0 'ST01: empty listing succeeds'
assert_eq '' "${T_OUT}" 'ST01: empty listing emits nothing'

t_case 'ST02: A remote-only conflicting tag in a large listing is rejected'
repo="$(tf_fixture_repo streams-guard)"
t_run in_repo "${repo}" bash "${ROOT}/scripts/release-prepare.sh" patch --mode production
assert_rc 0 'ST02: candidate prepared before conflicting tag exists'
branch="$(tf_kv "${T_OUT}" candidate_branch)"
commit="$(tf_kv "${T_OUT}" candidate_commit)"
git -C "${repo}" checkout --quiet "${branch}"
awk -v c="$(git -C "${repo}" rev-parse origin/develop)" 'BEGIN {
  print "create refs/tags/0.1.1 " c
  for (i=0; i<10000; i++) printf "create refs/tags/z-padding-%05d %s\n", i, c
}' | git --git-dir="${TF_TMP}/streams-guard.git" update-ref --stdin
before="$(git_state "${repo}" "${TF_TMP}/streams-guard.git" | sha256sum)"
t_run in_repo "${repo}" bash "${ROOT}/scripts/candidate-guard.sh" --ref "${branch}" --commit "${commit}"
assert_rc 1 'ST02: remote collision rejected'
assert_contains "${T_ERR}" 'Conflicting remote release tag' 'ST02: rejects the actual remote collision'
assert_eq "${before}" "$(git_state "${repo}" "${TF_TMP}/streams-guard.git" | sha256sum)" 'ST02: collision rejection changes no Git state'

t_case 'ST03: A remote candidate branch collision in a large listing is rejected'
repo="$(tf_fixture_repo streams-prepare)"
base="$(git -C "${repo}" rev-parse origin/develop)"
branch="release/0.1.1-${base:0:12}"
awk -v c="${base}" -v b="${branch}" 'BEGIN {
  print "create refs/heads/" b " " c
  for (i=0; i<10000; i++) printf "create refs/heads/z-padding-%05d %s\n", i, c
}' | git --git-dir="${TF_TMP}/streams-prepare.git" update-ref --stdin
before="$(git -C "${repo}" show-ref | sha256sum)"
remote_before="$(tf_remote_refs "${TF_TMP}/streams-prepare.git" | sha256sum)"
t_run in_repo "${repo}" bash "${ROOT}/scripts/release-prepare.sh" patch --mode production
assert_rc 1 'ST03: candidate branch collision rejected'
assert_contains "${T_ERR}" 'Branch collision: remote branch' 'ST03: names the actual branch collision'
assert_eq "${before}" "$(git -C "${repo}" show-ref | sha256sum)" 'ST03: no local branch created'
assert_eq "${remote_before}" "$(tf_remote_refs "${TF_TMP}/streams-prepare.git" | sha256sum)" 'ST03: no remote refs changed'
assert_eq 1 "$(git -C "${repo}" worktree list --porcelain | grep -c '^worktree ')" 'ST03: temporary candidate worktree removed'

# Managed files outside scripts/.github still belong to the release boundary.
# shellcheck disable=SC2317,SC2329 # Called by tf__release_setup.
managed_setup() {
  printf 'managed payload\n' > managed.txt
  jq -n '{schema_version:1, files: ([{path:"managed.txt"}] +
    [range(0;10000) | {path:("retired/padding-" + tostring)}])}' > .release-flow-bundle.json
}

t_case 'ST04: Large managed-file inventory cannot bypass promotion protection'
TF_RELEASE_EXTRA_SETUP=managed_setup
repo="$(tf_release_repo streams-managed)"
unset TF_RELEASE_EXTRA_SETUP
t_run in_repo "${repo}" bash "${ROOT}/scripts/release-prepare.sh" patch --mode production
assert_rc 0 'ST04: fixture candidate prepared'
branch="$(tf_kv "${T_OUT}" candidate_branch)"
git -C "${repo}" checkout --quiet "${branch}"
printf 'unauthorized candidate change\n' >> "${repo}/managed.txt"
git -C "${repo}" add managed.txt
git -C "${repo}" commit --quiet --amend --no-edit
commit="$(git -C "${repo}" rev-parse HEAD)"
git -C "${repo}" push --quiet origin "${branch}"
before="$(git_state "${repo}" "${TF_TMP}/streams-managed.git" | sha256sum)"
t_run bash "${ROOT}/scripts/release-promote.sh" --project-dir "${repo}" --candidate "${branch}" --commit "${commit}"
assert_rc 3 'ST04: promotion refused'
assert_contains "${T_ERR}" '[PF09] FAIL' 'ST04: managed-file protection rejects before CI/signing/push'
assert_contains "${T_ERR}" 'managed.txt' 'ST04: names the managed file'
assert_eq "${before}" "$(git_state "${repo}" "${TF_TMP}/streams-managed.git" | sha256sum)" 'ST04: protected state unchanged'

t_case 'ST05: Large remote history supports status, promotion and publisher recovery'
repo="$(tf_release_repo streams-flow)"
tf_candidate "${repo}"
awk -v c="${TF_C}" 'BEGIN {
  for (i=0; i<10000; i++) {
    printf "create refs/tags/0.0.%d %s\n", i, c
    printf "create refs/heads/release/2.2.2-%012x %s\n", i, c
  }
}' | git --git-dir="${TF_TMP}/streams-flow.git" update-ref --stdin
before="$(git_state "${repo}" "${TF_TMP}/streams-flow.git" | sha256sum)"
for version in 0.1.1 2.2.2; do
  t_run bash "${ROOT}/scripts/release-status.sh" --project-dir "${repo}" "${version}" --json
  assert_rc 0 "ST05: status for ${version} succeeds"
  assert_eq "${TF_C}" "$(printf '%s' "${T_OUT}" | jq -r .candidate_commit)" "ST05: status for ${version} names the right commit"
  if [[ "${version}" == 0.1.1 ]]; then expected=VALIDATED; else expected=PREPARED; fi
  assert_eq "${expected}" "$(printf '%s' "${T_OUT}" | jq -r .state)" "ST05: correct state for ${version}"
done
assert_eq "${before}" "$(git_state "${repo}" "${TF_TMP}/streams-flow.git" | sha256sum)" 'ST05: status stays read-only'
t_run bash "${ROOT}/scripts/release-promote.sh" --project-dir "${repo}" --candidate "${TF_BRANCH}" --commit "${TF_C}"
assert_rc 0 'ST05: promotion succeeds with many stable tags'
if (( T_RC == 0 )); then
  tag_before="$(git -C "${repo}" rev-parse refs/tags/0.1.1)"
  packages_before="$(grep -c '^package$' "${STUB_LOG}")"
  t_run bash "${ROOT}/scripts/publication/latest.sh" --project-dir "${repo}" --version 0.1.1
  assert_rc 0 'ST05: latest guard succeeds'
  assert_eq true "${T_OUT}" 'ST05: highest promoted release is latest'
  t_run bash "${ROOT}/scripts/release-retry.sh" --project-dir "${repo}" 0.1.1 github-release --local
  assert_rc 0 'ST05: publication recovers from retained artifacts'
  assert_eq "${tag_before}" "$(git -C "${repo}" rev-parse refs/tags/0.1.1)" 'ST05: recovery leaves signed tag unchanged'
  assert_eq "${packages_before}" "$(grep -c '^package$' "${STUB_LOG}")" 'ST05: recovery does not package again'
fi

t_case 'ST06: Large annotated tags preserve strict metadata validation'
tf_tag_message streams-flow acme/streams-flow "file://$(tf_store streams-flow)" > "${TF_TMP}/normal-message"
{
  sed -n '1p' "${TF_TMP}/normal-message"
  printf '\n'
  awk 'BEGIN { for (i=0; i<10000; i++) print "Additional release context without protocol fields." }'
  sed '1d' "${TF_TMP}/normal-message"
} > "${TF_TMP}/large-message"
# Create unreferenced annotated objects: never replace the promoted signed tag.
{
  printf 'object %s\ntype commit\ntag 0.1.1\ntagger Tester <tester@example.com> 1700000000 +0000\n\n' "${TF_C}"
  cat "${TF_TMP}/large-message"
} > "${TF_TMP}/large-tag"
large_tag="$(git -C "${repo}" hash-object -t tag -w "${TF_TMP}/large-tag")"
# shellcheck disable=SC2317,SC2329 # Called indirectly by t_run.
parse_tag() {
  bash -euo pipefail -c '
    source "$1/scripts/lib/common.sh"
    source "$1/scripts/lib/schema.sh"
    source "$1/scripts/lib/tag.sh"
    cd "$2"
    rf_tag_parse "$3"
  ' -- "${ROOT}" "${repo}" "$1"
}
t_run parse_tag "${large_tag}"
assert_rc 0 'ST06: large valid tag parses'
assert_eq "${TF_C}" "$(printf '%s' "${T_OUT}" | jq -r .candidate_commit)" 'ST06: tag binding preserved'
sed '/^Release-Version:/a Release-Version: 0.1.1' "${TF_TMP}/large-tag" > "${TF_TMP}/bad-tag"
bad_tag="$(git -C "${repo}" hash-object -t tag -w "${TF_TMP}/bad-tag")"
t_run parse_tag "${bad_tag}"
assert_rc 1 'ST06: duplicate trailer rejected'
assert_contains "${T_ERR}" 'duplicate trailers' 'ST06: metadata rejection, not SIGPIPE'
sed '/^Release-Commit:/d' "${TF_TMP}/large-tag" > "${TF_TMP}/bad-tag"
bad_tag="$(git -C "${repo}" hash-object -t tag -w "${TF_TMP}/bad-tag")"
t_run parse_tag "${bad_tag}"
assert_rc 1 'ST06: missing trailer rejected'
assert_contains "${T_ERR}" 'missing trailers' 'ST06: missing metadata still rejected'

t_case 'ST07: Remote transport failure after output cannot become a valid status'
mkdir "${TF_TMP}/failing-bin"
cat <<'EOF' > "${TF_TMP}/failing-bin/git"
#!/usr/bin/env bash
if [[ "${1:-}" == ls-remote ]]; then
  cat "${STREAM_REFS}"
  exit 42
fi
exec "${STREAM_REAL_GIT}" "$@"
EOF
chmod +x "${TF_TMP}/failing-bin/git"
before="$(git_state "${repo}" "${TF_TMP}/streams-flow.git" | sha256sum)"
t_run env PATH="${TF_TMP}/failing-bin:${PATH}" STREAM_REAL_GIT="${REAL_GIT}" STREAM_REFS="${refs}" \
  bash "${ROOT}/scripts/release-status.sh" --project-dir "${repo}" 0.1.1 --json
assert_rc 1 'ST07: producer failure propagated'
assert_eq '' "${T_OUT}" 'ST07: no success document after remote failure'
assert_contains "${T_ERR}" 'Cannot query' 'ST07: transport error reported'
assert_eq "${before}" "$(git_state "${repo}" "${TF_TMP}/streams-flow.git" | sha256sum)" 'ST07: failure changes no Git state'

t_case 'ST08: A forbidden early archive entry is rejected before any publication'
site="${TF_TMP}/site"
release_dir="${TF_TMP}/docs-release"
destination="${TF_TMP}/published-docs"
mkdir -p "${site}/empty" "${release_dir}/artifacts" "${destination}"
printf 'protected existing publication\n' > "${destination}/existing.html"
printf 'fixture page\n' > "${site}/index.html"
ln -s index.html "${site}/blocked.html"
awk 'BEGIN {
  print "blocked.html"
  for (i=0; i<70000; i++) print "empty/"
  print "index.html"
}' > "${TF_TMP}/tar-list"
tar -czf "${release_dir}/artifacts/docs.tar.gz" -C "${site}" --no-recursion -T "${TF_TMP}/tar-list"
sha="$(sha256sum "${release_dir}/artifacts/docs.tar.gz" | awk '{print $1}')"
jq -n --arg s "${sha}" '{artifacts:[{name:"docs.tar.gz",sha256:$s}]}' > "${release_dir}/artifacts/manifest.json"
jq -n '{manifest_sha256:("a" * 64)}' > "${release_dir}/release.json"
channel="$(jq -nc --arg u "file://${destination}" '{artifact:"docs.tar.gz",uri:$u,latest:true}')"
before="$(find "${destination}" -type f -exec sha256sum {} + | sort | sha256sum)"
for action in observe apply; do
  t_run env RF_PROJECT=streams RF_VERSION=1.2.3 RF_RELEASE_DIR="${release_dir}" RF_CHANNEL_CONFIG="${channel}" \
    RF_CONFIG_JSON='{}' RF_IS_LATEST=true bash "${ROOT}/scripts/publishers/docs.sh" "${action}"
  assert_rc 5 "ST08: ${action} rejects forbidden entry"
  assert_contains "${T_ERR}" 'neither regular files nor directories' "ST08: ${action} reports unsafe entry type"
  assert_eq "${before}" "$(find "${destination}" -type f -exec sha256sum {} + | sort | sha256sum)" "ST08: ${action} preserves destination bytes"
done

t_case 'ST09: Bundle upgrade drains a large ownership inventory'
bundle_archive="$(bash "${ROOT}/scripts/release-flow-bundle.sh" --version 9.9.9 --out "${TF_TMP}/bundle" 2>/dev/null)"
tar -xzf "${bundle_archive}" -C "${TF_TMP}/bundle"
bundle="${TF_TMP}/bundle/release-flow-bundle-9.9.9"
target="${TF_TMP}/install-target"
git init --quiet "${target}"
t_run bash "${bundle}/install.sh" --target "${target}"
assert_rc 0 'ST09: initial install succeeds'
jq '.files += [range(0;2000) | {path:("retired/" + ("padding" * 30) + tostring),
  sha256:("a" * 64),mode:"644"}]' "${target}/.release-flow-bundle.json" > "${TF_TMP}/large-lock"
mv "${TF_TMP}/large-lock" "${target}/.release-flow-bundle.json"
changed=.github/workflows/candidate.yml
printf '\n# New trusted bundle revision.\n' >> "${bundle}/payload/${changed}"
sha="$(sha256sum "${bundle}/payload/${changed}" | awk '{print $1}')"
jq --arg p "${changed}" --arg s "${sha}" '.payload |= map(if .path==$p then .sha256=$s else . end)' \
  "${bundle}/BUNDLE.json" > "${TF_TMP}/bundle-manifest"
mv "${TF_TMP}/bundle-manifest" "${bundle}/BUNDLE.json"
t_run bash "${bundle}/install.sh" --target "${target}" --upgrade
assert_rc 0 'ST09: upgrade with large lock succeeds'
assert_eq "${sha}" "$(sha256sum "${target}/${changed}" | awk '{print $1}')" 'ST09: expected managed file updated'
t_run bash "${bundle}/install.sh" --target "${target}" --check
assert_rc 0 'ST09: upgraded installation passes drift check'

# Exercise default GPG selection without generating keys or signing any tag.
# shellcheck disable=SC2317,SC2329 # Called by tf__release_setup.
gpg_setup() {
  jq '.promotion.signature_verification="github"' .release-flow.json > config.tmp
  mv config.tmp .release-flow.json
}

t_case 'ST10: Default GPG key selection drains output and preserves producer errors'
TF_RELEASE_EXTRA_SETUP=gpg_setup
repo="$(tf_release_repo streams-gpg)"
unset TF_RELEASE_EXTRA_SETUP
tf_candidate "${repo}"
git -C "${repo}" config gpg.format openpgp
git -C "${repo}" config --unset user.signingkey
tf_gh_put user '{"login":"tester"}'
tf_gh_put users/tester/gpg_keys '[{"key_id":"0123456789ABCDEF"}]'
mkdir "${TF_TMP}/gpg-bin"
cat <<'EOF' > "${TF_TMP}/gpg-bin/gpg"
#!/usr/bin/env bash
set -euo pipefail
[[ "$*" == '--list-secret-keys --with-colons' ]] || exit 2
awk 'BEGIN {
  print "sec:-:255:22:0123456789ABCDEF:1700000000:::::::"
  for (i=0; i<10000; i++) print "uid:-::::::::Additional identity on the fixture key::::::::"
  print "sec:-:255:22:FEDCBA9876543210:1700000000:::::::"
}'
exit "${STREAM_GPG_EXIT:-0}"
EOF
chmod +x "${TF_TMP}/gpg-bin/gpg"
before="$(git_state "${repo}" "${TF_TMP}/streams-gpg.git" | sha256sum)"
t_run env PATH="${TF_TMP}/gpg-bin:${PATH}" bash "${ROOT}/scripts/release-promote.sh" \
  --project-dir "${repo}" --candidate "${TF_BRANCH}" --commit "${TF_C}" --dry-run
assert_rc 0 'ST10: first registered GPG key selected'
assert_contains "${T_ERR}" 'GPG signing key 0123456789ABCDEF registered' 'ST10: original first-key precedence retained'
assert_eq "${before}" "$(git_state "${repo}" "${TF_TMP}/streams-gpg.git" | sha256sum)" 'ST10: dry run leaves Git unchanged'
t_run env PATH="${TF_TMP}/gpg-bin:${PATH}" STREAM_GPG_EXIT=42 bash "${ROOT}/scripts/release-promote.sh" \
  --project-dir "${repo}" --candidate "${TF_BRANCH}" --commit "${TF_C}" --dry-run
assert_rc 42 'ST10: GPG failure after valid output is preserved'
assert_eq '' "${T_OUT}" 'ST10: failed producer cannot report a successful promotion'
assert_eq "${before}" "$(git_state "${repo}" "${TF_TMP}/streams-gpg.git" | sha256sum)" 'ST10: GPG failure leaves Git unchanged'

t_case 'ST11: Large worktree listings cannot hide an active candidate worktree'
repo="$(tf_fixture_repo streams-worktrees)"
wt_root="${repo}/.git/release-flow/worktrees"
git -C "${repo}" worktree add --quiet --detach "${wt_root}/wt.active" origin/develop
mkdir "${TF_TMP}/worktree-bin"
cat <<'EOF' > "${TF_TMP}/worktree-bin/git"
#!/usr/bin/env bash
set -euo pipefail
if [[ "${1:-}" == worktree && "${2:-}" == list ]]; then
  "${STREAM_REAL_GIT}" "$@"
  awk 'BEGIN { for (i=0; i<10000; i++) printf "worktree /fixture/padding-%05d\nHEAD %040d\ndetached\n\n", i, i }'
  exit 0
fi
exec "${STREAM_REAL_GIT}" "$@"
EOF
chmod +x "${TF_TMP}/worktree-bin/git"
before="$(git_state "${repo}" "${TF_TMP}/streams-worktrees.git" | sha256sum)"
t_run in_repo "${repo}" env PATH="${TF_TMP}/worktree-bin:${PATH}" STREAM_REAL_GIT="${REAL_GIT}" \
  bash "${ROOT}/scripts/release-prepare.sh" patch --mode production
assert_rc 1 'ST11: active candidate worktree blocks preparation'
assert_contains "${T_ERR}" 'Existing active or stale candidate worktree' 'ST11: names the existing worktree guard'
assert_eq "${before}" "$(git_state "${repo}" "${TF_TMP}/streams-worktrees.git" | sha256sum)" 'ST11: active worktree and Git state preserved'

t_finish
