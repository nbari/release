#!/usr/bin/env bash
# Test the release-flow distribution bundle builder and installer.
set -euo pipefail
# shellcheck source=tests/pipeline/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

orig_dir="$(pwd)"
bundler="${ROOT}/scripts/release-flow-bundle.sh"

# build_bundle <version> <out-dir> [epoch]: prints archive path
build_bundle() {
  SOURCE_DATE_EPOCH="${3:-1700000000}" bash "${bundler}" --version "$1" --out "$2" 2>/dev/null
}

# extract_bundle <archive> <dir>: prints extracted bundle root
extract_bundle() {
  mkdir -p "$2"
  tar -xzf "$1" -C "$2"
  printf '%s/%s' "$2" "$(basename "$1" .tar.gz)"
}

# rehash <bundle-root> <section> <path>: refresh a BUNDLE.json checksum after editing
rehash() {
  local root="$1" section="$2" path="$3" prefix sum
  if [[ "${section}" == "payload" ]]; then prefix="payload/"; else prefix="optional/"; fi
  sum="$(sha256sum "${root}/${prefix}${path}" | awk '{print $1}')"
  jq --arg s "${section}" --arg p "${path}" --arg h "${sum}" \
    '.[$s] |= map(if .path == $p then .sha256 = $h else . end)' "${root}/BUNDLE.json" > "${root}/BUNDLE.json.tmp"
  mv "${root}/BUNDLE.json.tmp" "${root}/BUNDLE.json"
}

file_sha() {
  sha256sum "$1" | awk '{print $1}'
}

exists() {
  if [[ -e "$1" ]]; then echo present; else echo absent; fi
}

refs_of() {
  git -C "$1" for-each-ref --format='%(refname) %(objectname)' | sort
  git -C "$1" rev-parse HEAD
}

PAYLOAD_PATHS=".github/workflows/candidate.yml
.github/workflows/release.yml
.justfiles/deploy.just
scripts/candidate-guard.sh
scripts/candidate-manifest.sh
scripts/candidate-targets.sh
scripts/lib/common.sh
scripts/lib/github.sh
scripts/lib/project.sh
scripts/lib/schema.sh
scripts/lib/tag.sh
scripts/pipeline-pin.sh
scripts/publication/ci-install-oras.sh
scripts/publication/latest.sh
scripts/publication/ledger.sh
scripts/publication/plan.sh
scripts/publication/publish.sh
scripts/publication/resolve.sh
scripts/publishers/crates-io.sh
scripts/publishers/docs.sh
scripts/publishers/github-release.sh
scripts/publishers/helm.sh
scripts/publishers/oci.sh
scripts/release-candidates.sh
scripts/release-deploy.sh
scripts/release-prepare.sh
scripts/release-promote.sh
scripts/release-retry.sh
scripts/release-status.sh
scripts/storage/backends/fs.sh
scripts/storage/backends/github.sh
scripts/storage/backends/s3.sh
scripts/storage/ci-credentials.sh
scripts/storage/github-bootstrap.sh
scripts/storage/storage.sh
scripts/verify-candidate.sh"
PAYLOAD_COUNT=36
SUPPORT_DOCS="LICENSE
docs/BRANCHES.md
docs/CANDIDATES.md
docs/GITHUB_STORAGE.md
docs/MARKETPLACE.md
docs/callers/candidate.yml
docs/callers/release.yml
examples/shell/README.md
examples/shell/tools/adapter.sh
examples/shell/VERSION
examples/shell/app/hello.sh
examples/shell/.release-flow.json
docs/ADOPTION.md
docs/RULESETS.md
docs/release-flow.example.json
docs/rulesets/candidates.json
docs/rulesets/develop-integrity.json
docs/rulesets/develop-review.json
docs/rulesets/main-integrity.json
docs/rulesets/main-promotion.json
docs/rulesets/release-tags-create.json
docs/rulesets/release-tags-immutable.json"

t_case "B1: Reproducible bundle archives"
a1="$(build_bundle 9.9.9 "${TF_TMP}/b1-a")"
a2="$(build_bundle 9.9.9 "${TF_TMP}/b1-b")"
assert_eq "${TF_TMP}/b1-a/release-flow-bundle-9.9.9.tar.gz" "${a1}" "B1: archive path printed on stdout"
assert_eq "$(file_sha "${a1}")" "$(file_sha "${a2}")" "B1: identical SOURCE_DATE_EPOCH gives byte-identical archives"
t_run bash "${bundler}" --version 9.9.9 --out "${TF_TMP}/b1-a"
assert_rc 1 "B1: refuses to overwrite an existing archive"
t_run bash "${bundler}" --version 9.9 --out "${TF_TMP}/b1-c"
assert_rc 2 "B1: rejects a non-SemVer version"

t_case "B2: Bundle contents and BUNDLE.json"
expected_files="$(
  {
    printf '%s\n' "release-flow-bundle-9.9.9/BUNDLE.json" "release-flow-bundle-9.9.9/install.sh" \
      "release-flow-bundle-9.9.9/optional/scripts/adapters/cargo.sh"
    printf '%s\n' "${SUPPORT_DOCS}" | sed 's|^|release-flow-bundle-9.9.9/|'
    printf '%s\n' "${PAYLOAD_PATHS}" | sed 's|^|release-flow-bundle-9.9.9/payload/|'
  } | sort
)"
actual_files="$(tar -tzf "${a1}" | grep -v '/$' | sort)"
assert_eq "${expected_files}" "${actual_files}" "B2: archive file set matches the contract"
b2="$(extract_bundle "${a1}" "${TF_TMP}/b2")"
assert_eq "$(git -C "${ROOT}" rev-parse HEAD)" "$(jq -r .source_commit "${b2}/BUNDLE.json")" "B2: source_commit is the source HEAD"
assert_eq "9.9.9" "$(jq -r .bundle_version "${b2}/BUNDLE.json")" "B2: bundle_version recorded"
assert_eq "1.27.0" "$(jq -r .min_just "${b2}/BUNDLE.json")" "B2: min_just recorded"
assert_eq "${PAYLOAD_PATHS}" "$(jq -r '.payload[].path' "${b2}/BUNDLE.json")" "B2: payload paths sorted and complete"
mismatches=0
while IFS=$'\t' read -r p s; do
  [[ "$(file_sha "${b2}/payload/${p}")" == "${s}" ]] || mismatches=$(( mismatches + 1 ))
done <<< "$(jq -r '.payload[] | .path + "\t" + .sha256' "${b2}/BUNDLE.json")"
while IFS=$'\t' read -r p s; do
  [[ "$(file_sha "${b2}/optional/${p}")" == "${s}" ]] || mismatches=$(( mismatches + 1 ))
done <<< "$(jq -r '.optional[] | .path + "\t" + .sha256' "${b2}/BUNDLE.json")"
assert_eq "0" "${mismatches}" "B2: BUNDLE.json checksums match the extracted files"
assert_eq "755" "$(jq -r '.payload[] | select(.path == "scripts/release-deploy.sh") | .mode' "${b2}/BUNDLE.json")" "B2: scripts are mode 755"
assert_eq "644" "$(jq -r '.payload[] | select(.path == ".justfiles/deploy.just") | .mode' "${b2}/BUNDLE.json")" "B2: deploy.just is mode 644"

t_case "B3: Fresh install into a repository"
repo="$(tf_fixture_repo "bundle-fresh")"
refs_before="$(refs_of "${repo}")"
t_run bash "${b2}/install.sh" --target "${repo}"
assert_rc 0 "B3: install succeeds"
assert_contains "${T_OUT}" "bundle_version=9.9.9" "B3: reports bundle version"
assert_contains "${T_OUT}" "installed=${PAYLOAD_COUNT}" "B3: installs every payload file"
assert_contains "${T_ERR}" "import '.justfiles/deploy.just'" "B3: prints the import instruction"
assert_not_contains "${T_ERR}" "release-flow.example.json" "B3: no config instruction when .release-flow.json exists"
missing=0
while IFS= read -r p; do
  [[ -f "${repo}/${p}" ]] || missing=$(( missing + 1 ))
done <<< "${PAYLOAD_PATHS}"
assert_eq "0" "${missing}" "B3: payload files present"
assert_eq "present" "$( [[ -x "${repo}/scripts/release-deploy.sh" ]] && echo present || echo absent)" "B3: scripts executable"
assert_eq "absent" "$( [[ -x "${repo}/.justfiles/deploy.just" ]] && echo present || echo absent)" "B3: deploy.just not executable"
assert_eq "absent" "$(exists "${repo}/scripts/adapters/cargo.sh")" "B3: optional cargo adapter not installed by default"
assert_eq "9.9.9" "$(jq -r .bundle_version "${repo}/.release-flow-bundle.json")" "B3: lock file written"
assert_eq "${refs_before}" "$(refs_of "${repo}")" "B3: no refs or commits created"
assert_eq "" "$(git -C "${repo}" diff --cached --name-only)" "B3: nothing staged"
rm -f "${repo}/.release-flow.json"
t_run bash "${b2}/install.sh" --target "${repo}"
assert_rc 0 "B3: re-install is idempotent"
assert_contains "${T_OUT}" "unchanged=${PAYLOAD_COUNT}" "B3: re-install leaves identical files"
assert_contains "${T_ERR}" "release-flow.example.json" "B3: config instruction when .release-flow.json is missing"
t_run bash "${b2}/install.sh" --target "${repo}/tools"
assert_rc 2 "B3: target must be the work-tree root"
t_run bash "${ROOT}/scripts/release-flow-install.sh" --target "${repo}"
assert_rc 2 "B3: installer outside an extracted bundle is a usage error"
assert_contains "${T_ERR}" "run install.sh from an extracted bundle" "B3: explains where to run install.sh"

t_case "B4: Conflicting unmanaged file"
repo="$(tf_fixture_repo "bundle-conflict")"
mkdir -p "${repo}/scripts"
printf '#!/usr/bin/env bash\necho custom\n' > "${repo}/scripts/release-prepare.sh"
custom_sha="$(file_sha "${repo}/scripts/release-prepare.sh")"
t_run bash "${b2}/install.sh" --target "${repo}"
assert_rc 1 "B4: conflict fails install"
assert_contains "${T_ERR}" "scripts/release-prepare.sh" "B4: names the conflicting path"
assert_eq "${custom_sha}" "$(file_sha "${repo}/scripts/release-prepare.sh")" "B4: conflicting file untouched"
assert_eq "absent" "$(exists "${repo}/.justfiles/deploy.just")" "B4: nothing written"
assert_eq "absent" "$(exists "${repo}/.release-flow-bundle.json")" "B4: no lock written"

t_case "B5: Upgrade"
a_next="$(build_bundle 9.9.10 "${TF_TMP}/b5")"
b5="$(extract_bundle "${a_next}" "${TF_TMP}/b5-x")"
printf '# upgraded\n' >> "${b5}/payload/scripts/release-deploy.sh"
rehash "${b5}" payload scripts/release-deploy.sh
jq '.payload |= map(select(.path != "scripts/verify-candidate.sh"))' "${b5}/BUNDLE.json" > "${b5}/BUNDLE.json.tmp"
mv "${b5}/BUNDLE.json.tmp" "${b5}/BUNDLE.json"
repo="$(tf_fixture_repo "bundle-upgrade")"
bash "${b2}/install.sh" --target "${repo}" >/dev/null 2>&1
t_run bash "${b5}/install.sh" --target "${repo}"
assert_rc 1 "B5: different installed version without --upgrade fails"
assert_contains "${T_ERR}" "already installed 9.9.9" "B5: names installed version"
t_run bash "${b5}/install.sh" --target "${repo}" --upgrade
assert_rc 0 "B5: --upgrade succeeds"
assert_contains "${T_OUT}" "updated=1" "B5: unchanged-by-user file overwritten"
assert_contains "${T_OUT}" "removed=1" "B5: file dropped from the bundle removed"
assert_eq "$(file_sha "${b5}/payload/scripts/release-deploy.sh")" "$(file_sha "${repo}/scripts/release-deploy.sh")" "B5: new content installed"
assert_eq "absent" "$(exists "${repo}/scripts/verify-candidate.sh")" "B5: removed file deleted"
assert_eq "9.9.10" "$(jq -r .bundle_version "${repo}/.release-flow-bundle.json")" "B5: lock updated"
repo="$(tf_fixture_repo "bundle-upgrade-conflict")"
bash "${b2}/install.sh" --target "${repo}" >/dev/null 2>&1
printf '# local change\n' >> "${repo}/scripts/release-deploy.sh"
local_sha="$(file_sha "${repo}/scripts/release-deploy.sh")"
lock_sha="$(file_sha "${repo}/.release-flow-bundle.json")"
t_run bash "${b5}/install.sh" --target "${repo}" --upgrade
assert_rc 1 "B5: locally modified file conflicts on upgrade"
assert_contains "${T_ERR}" "scripts/release-deploy.sh" "B5: names the modified file"
assert_eq "${local_sha}" "$(file_sha "${repo}/scripts/release-deploy.sh")" "B5: modified file untouched"
assert_eq "present" "$(exists "${repo}/scripts/verify-candidate.sh")" "B5: nothing removed on conflict"
assert_eq "${lock_sha}" "$(file_sha "${repo}/.release-flow-bundle.json")" "B5: lock untouched on conflict"

t_case "B6: --check drift detection"
repo="$(tf_fixture_repo "bundle-check")"
bash "${b2}/install.sh" --target "${repo}" >/dev/null 2>&1
t_run bash "${b2}/install.sh" --target "${repo}" --check
assert_rc 0 "B6: clean install passes --check"
assert_contains "${T_OUT}" "drift=0" "B6: reports no drift"
printf '# drift\n' >> "${repo}/scripts/candidate-guard.sh"
drift_sha="$(file_sha "${repo}/scripts/candidate-guard.sh")"
lock_sha="$(file_sha "${repo}/.release-flow-bundle.json")"
t_run bash "${b2}/install.sh" --target "${repo}" --check
assert_rc 1 "B6: drift fails --check"
assert_contains "${T_ERR}" "scripts/candidate-guard.sh" "B6: names the drifted file"
assert_eq "${drift_sha}" "$(file_sha "${repo}/scripts/candidate-guard.sh")" "B6: --check is read-only (file)"
assert_eq "${lock_sha}" "$(file_sha "${repo}/.release-flow-bundle.json")" "B6: --check is read-only (lock)"

t_case "B7: Tampered bundle"
b7="$(extract_bundle "${a1}" "${TF_TMP}/b7")"
printf '# tampered\n' >> "${b7}/payload/scripts/release-prepare.sh"
repo="$(tf_fixture_repo "bundle-tampered")"
t_run bash "${b7}/install.sh" --target "${repo}"
assert_rc 1 "B7: checksum mismatch fails install"
assert_contains "${T_ERR}" "checksum mismatch" "B7: reports checksum mismatch"
assert_eq "absent" "$(exists "${repo}/scripts/release-prepare.sh")" "B7: nothing written"
assert_eq "absent" "$(exists "${repo}/.release-flow-bundle.json")" "B7: no lock written"

t_case "B8: Framework adapter needs no Cargo project"
cd "${ROOT}"
t_run "${ROOT}/scripts/adapters/framework.sh" inventory 9.9.9
assert_rc 0 "B8: framework inventory succeeds"
assert_eq "release-flow-bundle-9.9.9.tar.gz:any" "$(jq -r '.artifacts[]|.name+":"+.target' <<< "$T_OUT")" "B8: only the framework bundle is declared"
t_run "${ROOT}/scripts/adapters/framework.sh" targets
assert_rc 0 "B8: framework targets succeed"
assert_eq '[{"target":"any","runner":"ubuntu-24.04"}]' "$T_OUT" "B8: a single shell packaging leg"
t_run bash "${ROOT}/scripts/candidate-targets.sh" --adapter scripts/adapters/framework.sh
assert_rc 0 "B8: candidate matrix accepts the framework adapter"
t_run "${ROOT}/scripts/adapters/framework.sh" bogus
assert_rc 2 "B8: unknown command fails"
cd "${orig_dir}"

t_case "B9: Optional Cargo adapter install and upgrade"
repo="$(tf_fixture_repo "bundle-cargo")"
lock="${repo}/.release-flow-bundle.json"
t_run bash "${b2}/install.sh" --target "${repo}" --with-cargo-adapter
assert_rc 0 "B9: --with-cargo-adapter install succeeds"
assert_contains "${T_OUT}" "installed=$(( PAYLOAD_COUNT + 1 ))" "B9: installs payload plus the cargo adapter"
assert_eq "$(file_sha "${b2}/optional/scripts/adapters/cargo.sh")" "$(file_sha "${repo}/scripts/adapters/cargo.sh")" "B9: cargo adapter content installed"
assert_eq "present" "$( [[ -x "${repo}/scripts/adapters/cargo.sh" ]] && echo present || echo absent)" "B9: cargo adapter executable"
assert_eq "$(jq -r '.optional[] | select(.path == "scripts/adapters/cargo.sh") | .sha256' "${b2}/BUNDLE.json")" \
  "$(jq -r '.files[] | select(.path == "scripts/adapters/cargo.sh") | .sha256' "${lock}")" "B9: cargo adapter recorded in the lock"
t_run bash "${b5}/install.sh" --target "${repo}" --upgrade
assert_rc 0 "B9: --upgrade without --with-cargo-adapter succeeds"
assert_eq "present" "$(exists "${repo}/scripts/adapters/cargo.sh")" "B9: --upgrade keeps the installed cargo adapter"
assert_eq "scripts/adapters/cargo.sh" "$(jq -r '.files[] | select(.path == "scripts/adapters/cargo.sh") | .path' "${lock}")" "B9: upgraded lock still records the cargo adapter"
assert_eq "9.9.10" "$(jq -r .bundle_version "${lock}")" "B9: lock upgraded"
t_run bash "${b5}/install.sh" --target "${repo}" --check
assert_rc 0 "B9: --check passes after upgrade"
assert_contains "${T_OUT}" "checked=${PAYLOAD_COUNT}" "B9: --check covers the cargo adapter (payload minus the file 9.9.10 dropped)"

t_case "B10: Symlinked or non-regular destinations"
repo="$(tf_fixture_repo "bundle-symlink-parent")"
outside="${TF_TMP}/b10-outside"
mkdir -p "${outside}"
ln -s "${outside}" "${repo}/scripts"
t_run bash "${b2}/install.sh" --target "${repo}"
assert_rc 1 "B10: symlinked parent directory fails install"
assert_contains "${T_ERR}" "scripts/release-prepare.sh: parent scripts is a symlink or not a directory" "B10: names the symlinked parent"
assert_eq "" "$(ls -A "${outside}")" "B10: nothing written through the symlink"
assert_eq "absent" "$(exists "${repo}/.justfiles/deploy.just")" "B10: nothing written"
assert_eq "absent" "$(exists "${repo}/.release-flow-bundle.json")" "B10: no lock written"

repo="$(tf_fixture_repo "bundle-symlink-upgrade")"
bash "${b2}/install.sh" --target "${repo}" >/dev/null 2>&1
moved="${TF_TMP}/b10-moved-scripts"
mv "${repo}/scripts" "${moved}"
ln -s "${moved}" "${repo}/scripts"
lock_sha="$(file_sha "${repo}/.release-flow-bundle.json")"
t_run bash "${b5}/install.sh" --target "${repo}" --upgrade
assert_rc 1 "B10: symlinked parent fails upgrade"
assert_contains "${T_ERR}" "scripts/verify-candidate.sh: parent scripts" "B10: names the removal through the symlink"
assert_eq "present" "$(exists "${moved}/verify-candidate.sh")" "B10: nothing deleted through the symlink"
assert_eq "$(file_sha "${b2}/payload/scripts/release-deploy.sh")" "$(file_sha "${moved}/release-deploy.sh")" "B10: nothing overwritten through the symlink"
assert_eq "${lock_sha}" "$(file_sha "${repo}/.release-flow-bundle.json")" "B10: lock untouched"
t_run bash "${b2}/install.sh" --target "${repo}" --check
assert_rc 1 "B10: --check reports a symlinked parent as drift"
assert_contains "${T_ERR}" "drift: scripts/candidate-guard.sh (parent scripts" "B10: --check names the symlinked parent"

repo="$(tf_fixture_repo "bundle-symlink-file")"
bash "${b2}/install.sh" --target "${repo}" >/dev/null 2>&1
cp -p "${repo}/scripts/candidate-guard.sh" "${TF_TMP}/b10-guard.sh"
rm "${repo}/scripts/candidate-guard.sh"
ln -s "${TF_TMP}/b10-guard.sh" "${repo}/scripts/candidate-guard.sh"
t_run bash "${b2}/install.sh" --target "${repo}" --check
assert_rc 1 "B10: --check rejects a symlinked managed file with identical content"
assert_contains "${T_ERR}" "drift: scripts/candidate-guard.sh (symlink)" "B10: --check names the symlinked file"

for kind in directory symlink; do
  repo="$(tf_fixture_repo "bundle-lock-${kind}")"
  if [[ "${kind}" == "directory" ]]; then
    lock_target="${repo}/.release-flow-bundle.json"
    mkdir "${lock_target}"
  else
    lock_target="${TF_TMP}/b10-lock-target"
    mkdir "${lock_target}"
    ln -s "${lock_target}" "${repo}/.release-flow-bundle.json"
  fi
  t_run bash "${b2}/install.sh" --target "${repo}"
  assert_rc 1 "B10: lock path ${kind} fails install"
  assert_contains "${T_ERR}" "conflict: .release-flow-bundle.json: exists and is not a regular file" "B10: lock path ${kind} reported as conflict"
  assert_eq "absent" "$(exists "${repo}/scripts/release-prepare.sh")" "B10: lock path ${kind}: nothing written"
  assert_eq "" "$(ls -A "${lock_target}")" "B10: lock path ${kind}: nothing written into the lock path"
  t_run bash "${b2}/install.sh" --target "${repo}" --check
  assert_rc 1 "B10: lock path ${kind} fails --check"
done

t_case "B11: Framework packaging builds its own clean pinned bundle"
src="${TF_TMP}/b11-src"
for f in action.yml VERSION .release-flow.json scripts/action.sh scripts/adapters/framework.sh scripts/adapters/cargo.sh scripts/release-flow-bundle.sh \
  scripts/release-flow-install.sh ${PAYLOAD_PATHS} ${SUPPORT_DOCS}; do
  mkdir -p "$(dirname "${src}/${f}")"
  cp -p "${ROOT}/${f}" "${src}/${f}"
done
printf '0.3.0\n' > "$src/VERSION"
git -C "$src" init --quiet
git -C "$src" add .
git -C "$src" commit --quiet -m "Record framework fixture"
cd "$src"
dist="${TF_TMP}/b11-dist"
SOURCE_DATE_EPOCH=1700000000 t_run scripts/adapters/framework.sh package 0.3.0 "$dist"
assert_rc 0 "B11: shell-only package succeeds"
assert_eq release-flow-bundle-0.3.0.tar.gz "$(find "$dist" -maxdepth 1 -type f -printf '%f\n')" "B11: package exactly matches inventory"
b11="$(extract_bundle "$dist/release-flow-bundle-0.3.0.tar.gz" "${TF_TMP}/b11-extract")"
assert_eq 0.3.0 "$(jq -r .bundle_version "$b11/BUNDLE.json")" "B11: bundle version matches VERSION"
assert_eq "$(git rev-parse HEAD)" "$(jq -r .source_commit "$b11/BUNDLE.json")" "B11: source SHA is exact"
assert_eq true "$(jq -r .source_tree_clean "$b11/BUNDLE.json")" "B11: clean provenance"
assert_eq nbari/release "$(jq -r .pipeline.repository "$b11/examples/shell/.release-flow.json")" "B11: framework repository identity"
assert_eq "$(git rev-parse HEAD)" "$(jq -r .pipeline.sha "$b11/examples/shell/.release-flow.json")" "B11: consumer pin matches runtime"
assert_eq reusable "$(jq -r .workflow_mode "$b11/BUNDLE.json")" "B11: thin reusable callers"
t_run scripts/adapters/framework.sh package 0.3.0
assert_rc 2 "B11: missing outdir fails"
SOURCE_DATE_EPOCH=1700000000 t_run scripts/adapters/framework.sh package 0.3.0 "$dist"
assert_rc 1 "B11: existing output fails"
SOURCE_DATE_EPOCH=1700000000 t_run scripts/adapters/framework.sh package 0.3.1 "${TF_TMP}/wrong-version"
assert_rc 1 "B11: version mismatch fails"
cd "$orig_dir"

t_case "B12: Malformed BUNDLE.json"
n=0
for filter in 'del(.optional)' '.payload = {}' '.payload[0].mode = "777"' 'del(.payload[0].path)'; do
  n=$(( n + 1 ))
  b12="$(extract_bundle "${a1}" "${TF_TMP}/b12-${n}")"
  jq "${filter}" "${b12}/BUNDLE.json" > "${b12}/BUNDLE.json.tmp"
  mv "${b12}/BUNDLE.json.tmp" "${b12}/BUNDLE.json"
  repo="$(tf_fixture_repo "bundle-malformed-${n}")"
  t_run bash "${b12}/install.sh" --target "${repo}"
  assert_rc 1 "B12 '${filter}': rejected"
  assert_contains "${T_ERR}" "Unsupported or invalid BUNDLE.json" "B12 '${filter}': explains invalid manifest"
  assert_eq "absent" "$(exists "${repo}/.release-flow-bundle.json")" "B12 '${filter}': no lock written"
  assert_eq "absent" "$(exists "${repo}/.justfiles/deploy.just")" "B12 '${filter}': nothing written"
done

t_case "B13: Reusable bundles pin callers and configuration to clean source"
source_repo="${TF_TMP}/bundle-source"
git init --quiet "${source_repo}"
for path in scripts docs examples .github .justfiles; do
  cp -R "${ROOT}/${path}" "${source_repo}/${path}"
done
for f in action.yml VERSION LICENSE .release-flow.json; do cp "${ROOT}/$f" "${source_repo}/$f"; done
git -C "${source_repo}" add .
git -C "${source_repo}" commit --quiet -m "Record bundle sources"
source_sha="$(git -C "${source_repo}" rev-parse HEAD)"
t_run bash "${source_repo}/scripts/release-flow-bundle.sh" --version 9.9.8 --out "${TF_TMP}/reusable-out" --workflow-mode reusable
assert_rc 0 "B13: clean reusable bundle builds"
reusable="$(extract_bundle "${T_OUT}" "${TF_TMP}/reusable-extract")"
assert_contains "$(cat "${reusable}/payload/.github/workflows/candidate.yml")" "candidate.yml@${source_sha}" "B13: candidate pinned"
assert_contains "$(cat "${reusable}/payload/.github/workflows/release.yml")" "release.yml@${source_sha}" "B13: release pinned"
assert_eq "${source_sha}" "$(jq -r .pipeline.sha "${reusable}/docs/release-flow.example.json")" "B13: example pin matches"
assert_eq reusable "$(jq -r .workflow_mode "${reusable}/BUNDLE.json")" "B13: mode recorded"
repo="$(tf_fixture_repo bundle-reusable)"
t_run bash "${reusable}/install.sh" --target "${repo}"
assert_rc 0 "B13: installs"
assert_contains "${T_ERR}" "pipeline.sha=${source_sha}" "B13: explains config upgrade"
t_run bash "${reusable}/install.sh" --target "${repo}"
assert_rc 0 "B13: idempotent install"
t_run bash "${reusable}/install.sh" --target "${repo}" --check
assert_rc 0 "B13: checks rendered checksums"
printf '\n# dirty\n' >> "${source_repo}/scripts/lib/common.sh"
t_run bash "${source_repo}/scripts/release-flow-bundle.sh" --version 9.9.7 --out "${TF_TMP}/dirty-out" --workflow-mode reusable
assert_rc 1 "B13: dirty source cannot claim pinned runtime"

t_case "B14: Installer temporary files cannot follow planted symlinks"
repo="$(tf_fixture_repo bundle-temp-link)"
outside="${TF_TMP}/outside-installer"
printf 'preserve outside bytes\n' > "${outside}"
mkdir -p "${repo}/scripts"
# The inner shell must expand its own PID for the attack reproduction.
# shellcheck disable=SC2016
t_run bash -c '
  ln -s "$3" "$2/scripts/release-deploy.sh.release-flow-tmp.$$"
  ln -s "$3" "$2/.release-flow-bundle.json.tmp.$$"
  exec bash "$1/install.sh" --target "$2"
' _ "${b2}" "${repo}" "${outside}"
assert_rc 0 "B14: install succeeds without using predictable paths"
assert_eq 'preserve outside bytes' "$(cat "${outside}")" "B14: never writes through temporary symlink"
assert_eq regular "$([[ ! -L "${repo}/scripts/release-deploy.sh" ]] && echo regular || echo symlink)" "B14: managed destination stays regular"

t_case "B15: Framework verification invokes the project gate"
verify_root="${TF_TMP}/framework-verify"
mkdir -p "$verify_root/scripts/adapters"
cp "$ROOT/scripts/adapters/framework.sh" "$verify_root/scripts/adapters/framework.sh"
printf 'check:\n    @true\n' > "$verify_root/.justfile"
cd "$verify_root"
t_run scripts/adapters/framework.sh verify
assert_rc 0 "B15: project check runs"
printf 'check:\n    @false\n' > .justfile
t_run scripts/adapters/framework.sh verify
assert_rc nonzero "B15: project check failures propagate"
cd "$orig_dir"

t_case "B16: GitHub consumer profile removes unused managed runtime safely"
git -C "$source_repo" checkout -- scripts/lib/common.sh
t_run bash "$source_repo/scripts/release-flow-bundle.sh" --version 9.9.11 --out "$TF_TMP/github-profile" --workflow-mode reusable --profile github
assert_rc 0 "B16: clean GitHub profile builds"
if (( T_RC != 0 )); then t_finish; fi
github_profile="$(extract_bundle "$T_OUT" "$TF_TMP/github-profile-extract")"
assert_eq github "$(jq -r .profile "$github_profile/BUNDLE.json")" "B16: profile is explicit"
assert_eq 21 "$(jq '.payload|length' "$github_profile/BUNDLE.json")" "B16: only the local command dependency set is shipped"
for omitted in lib/project.sh candidate-guard.sh candidate-manifest.sh candidate-targets.sh pipeline-pin.sh \
    publication/plan.sh publication/ci-install-oras.sh storage/ci-credentials.sh storage/github-bootstrap.sh \
    storage/backends/fs.sh storage/backends/s3.sh publishers/crates-io.sh publishers/docs.sh publishers/helm.sh publishers/oci.sh; do
  assert_eq absent "$(exists "$github_profile/payload/scripts/$omitted")" "B16: excludes $omitted"
done
t_run bash "$source_repo/scripts/release-flow-bundle.sh" --version 9.9.11 --out "$TF_TMP/github-vendored" --profile github
assert_rc 2 "B16: GitHub profile requires centralized reusable workflows"
t_run bash "$source_repo/scripts/release-flow-bundle.sh" --version 9.9.11 --out "$TF_TMP/unknown-profile" --profile unknown
assert_rc 2 "B16: unknown profile fails closed"

repo="$(tf_fixture_repo bundle-github-profile)"
bash "$b2/install.sh" --target "$repo" --with-cargo-adapter >/dev/null 2>&1
printf '# preserve my edit\n' >> "$repo/scripts/publishers/oci.sh"
lock_before="$(file_sha "$repo/.release-flow-bundle.json")"
t_run bash "$github_profile/install.sh" --target "$repo" --upgrade
assert_rc 1 "B16: locally edited unused script blocks profile upgrade"
assert_contains "$T_ERR" "publishers/oci.sh" "B16: conflict identifies the edited file"
assert_eq "$lock_before" "$(file_sha "$repo/.release-flow-bundle.json")" "B16: conflict preserves lock"
assert_eq present "$(exists "$repo/scripts/candidate-guard.sh")" "B16: conflict removes nothing"
cp "$b2/payload/scripts/publishers/oci.sh" "$repo/scripts/publishers/oci.sh"
t_run bash "$github_profile/install.sh" --target "$repo" --upgrade
assert_rc 0 "B16: full-to-GitHub upgrade succeeds"
assert_contains "$T_OUT" "removed=15" "B16: removes exactly the unused managed scripts"
assert_eq 22 "$(jq '.files|length' "$repo/.release-flow-bundle.json")" "B16: optional installed Cargo adapter survives upgrade"
assert_eq github "$(jq -r .profile "$repo/.release-flow-bundle.json")" "B16: installed profile is recorded"
assert_eq present "$(exists "$repo/scripts/adapters/cargo.sh")" "B16: keeps generic Cargo support"
t_run bash "$github_profile/install.sh" --target "$repo" --check
assert_rc 0 "B16: installed checksums pass"
t_run bash "$github_profile/install.sh" --target "$repo"
assert_rc 0 "B16: GitHub install is idempotent"
t_run bash "$repo/scripts/storage/storage.sh" --uri file:///unused head key
assert_rc 3 "B16: missing backend fails before use"
assert_contains "$T_ERR" "full bundle" "B16: explains how to install other backends"
t_run bash "$b2/install.sh" --target "$repo" --upgrade
assert_rc 0 "B16: full installation remains available"
assert_eq present "$(exists "$repo/scripts/storage/backends/s3.sh")" "B16: restores omitted features through installer"

same_version="$(extract_bundle "$TF_TMP/github-profile/release-flow-bundle-9.9.11.tar.gz" "$TF_TMP/github-same-version")"
jq '.bundle_version="9.9.9"' "$same_version/BUNDLE.json" > "$same_version/BUNDLE.json.tmp"
mv "$same_version/BUNDLE.json.tmp" "$same_version/BUNDLE.json"
t_run bash "$same_version/install.sh" --target "$repo"
assert_rc 1 "B16: changing profile requires explicit upgrade even at same version"
assert_contains "$T_ERR" "--upgrade" "B16: explains profile change consent"
assert_eq present "$(exists "$repo/scripts/publishers/oci.sh")" "B16: implicit profile switch removes nothing"

for config in '{"storage":{"uri":"s3://bucket/releases"}}' '{"publishers":{"oci":{}}}'; do
  repo="$(tf_fixture_repo "bundle-profile-policy-$RANDOM")"
  printf '%s\n' "$config" > "$repo/.release-flow.json"
  t_run bash "$github_profile/install.sh" --target "$repo"
  assert_rc 1 "B16: incompatible consumer configuration is rejected"
  assert_contains "$T_ERR" "GitHub profile" "B16: reports configuration mismatch"
  assert_eq absent "$(exists "$repo/.release-flow-bundle.json")" "B16: mismatch writes nothing"
done

for value in '"unknown"' false; do
  malformed="$(extract_bundle "$TF_TMP/github-profile/release-flow-bundle-9.9.11.tar.gz" "$TF_TMP/profile-value-$value")"
  jq --argjson value "$value" '.profile=$value' "$malformed/BUNDLE.json" > "$malformed/BUNDLE.json.tmp"
  mv "$malformed/BUNDLE.json.tmp" "$malformed/BUNDLE.json"
  repo="$(tf_fixture_repo "bundle-profile-invalid-$RANDOM")"
  t_run bash "$malformed/install.sh" --target "$repo"
  assert_rc 1 "B16: malformed profile metadata is rejected"
  assert_contains "$T_ERR" 'Invalid bundle profile' "B16: malformed profile does not select full implicitly"
  assert_eq absent "$(exists "$repo/.release-flow-bundle.json")" "B16: invalid profile writes nothing"
done
repo="$(tf_fixture_repo bundle-profile-symlink-config)"
cp "$repo/.release-flow.json" "$TF_TMP/profile-config-outside.json"
rm "$repo/.release-flow.json"
ln -s "$TF_TMP/profile-config-outside.json" "$repo/.release-flow.json"
t_run bash "$github_profile/install.sh" --target "$repo"
assert_rc 1 "B16: profile validation rejects a redirected consumer configuration"
assert_eq absent "$(exists "$repo/.release-flow-bundle.json")" "B16: redirected config writes nothing"

t_case "B17: GitHub profile preserves production and explicit test deploy commands"
for recipe in deploy deploy-minor deploy-major; do
  repo="$(tf_fixture_repo "profile-$recipe")"
  bash "$github_profile/install.sh" --target "$repo" >/dev/null 2>&1
  printf "import '.justfiles/deploy.just'\n" > "$repo/.justfile"
  git -C "$repo" add .
  git -C "$repo" commit --quiet -m "Install the consumer tooling"
  git -C "$repo" push --quiet origin sandbox
  git -C "$repo" checkout --quiet -B develop
  git -C "$repo" push --quiet origin develop
  before="$(git -C "$repo" rev-parse HEAD)"
  t_run just --justfile "$repo/.justfile" --working-directory "$repo" "$recipe"
  assert_rc 0 "B17: $recipe creates a candidate without omitted scripts"
  assert_contains "$T_OUT" 'mode=production' "B17: $recipe selects production on develop"
  case "$recipe" in deploy) expected=0.1.1 ;; deploy-minor) expected=0.2.0 ;; deploy-major) expected=1.0.0 ;; esac
  assert_contains "$T_OUT" "version=$expected" "B17: $recipe selects the correct version"
  assert_eq "$before" "$(git -C "$repo" rev-parse HEAD)" "B17: $recipe preserves the base commit"
  assert_eq 0.1.0 "$(cat "$repo/VERSION")" "B17: $recipe preserves the working version"
  git -C "$repo" checkout --quiet sandbox
  before="$(tf_snapshot "$repo")"
  t_run just --justfile "$repo/.justfile" --working-directory "$repo" "$recipe"
  assert_rc 3 "B17: $recipe refuses sandbox"
  assert_eq "$before" "$(tf_snapshot "$repo")" "B17: $recipe rejection leaves Git unchanged"
  case "$recipe" in deploy) bump="patch" ;; deploy-minor) bump="minor" ;; deploy-major) bump="major" ;; esac
  t_run just --justfile "$repo/.justfile" --working-directory "$repo" deploy-test "$bump"
  assert_rc 0 "B17: explicit test $bump creates a candidate"
  assert_contains "$T_OUT" 'mode=test-only' "B17: explicit test $bump stays test-only"
  assert_contains "$T_OUT" "version=$expected" "B17: explicit test $bump selects the correct version"
done
t_finish
