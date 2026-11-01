# Migration inventory

Source: `https://github.com/nbari/release-flow` at full commit
`8c7d444b9e47ae28d0864e8d9fc3c936530f5b5f`. The existing destination
history starts at `3ae48ffd5236a6844ca835de0fa033a88d8405ad` and is preserved.

Categories: A framework; B Rust application; C shared metadata adapted independently;
D historical evidence; E obsolete material. No historical release object is obsolete.
Prepared metadata-length and agent-signing fixes accompany this extraction.

| Source tracked path | Category | Disposition |
| --- | --- | --- |
| `.github/workflows/candidate.yml` | A | Move active ownership to nbari/release |
| `.github/workflows/ci.yml` | C | Independent framework CI and independent Rust CI |
| `.github/workflows/release.yml` | A | Move active ownership to nbari/release |
| `.gitignore` | C | Keep repository-specific generated-file exclusions |
| `.justfile` | C | Framework operations/tests; Rust-only Cargo recipes |
| `.justfiles/deploy.just` | A | Move active ownership to nbari/release |
| `.release-flow.json` | C | Framework self-config; remove from Rust until future adoption |
| `AGENTS.md` | C | Write independent framework and Rust guidelines without agent tooling |
| `Cargo.lock` | B | Keep in nbari/release-flow |
| `Cargo.toml` | B | Keep in nbari/release-flow |
| `LICENSE` | C | Preserve BSD-3-Clause in both histories |
| `README.md` | C | Write separate framework product and Rust CLI introductions |
| `action.yml` | A | Move active ownership to nbari/release |
| `build.rs` | B | Keep in nbari/release-flow |
| `docs/ADOPTION.md` | A | Move active ownership to nbari/release |
| `docs/BRANCHES.md` | A | Move active ownership to nbari/release |
| `docs/CANDIDATES.md` | A | Move active ownership to nbari/release |
| `docs/GITHUB_STORAGE.md` | A | Move active ownership to nbari/release |
| `docs/MARKETPLACE.md` | A | Move active ownership to nbari/release |
| `docs/RELEASE_DESIGN.md` | A | Move active ownership to nbari/release |
| `docs/RULESETS.md` | A | Move active ownership to nbari/release |
| `docs/VERIFICATION.md` | D | Preserve historical links and record migration origin |
| `docs/callers/candidate.yml` | A | Move active ownership to nbari/release |
| `docs/callers/release.yml` | A | Move active ownership to nbari/release |
| `docs/release-flow.example.json` | A | Move active ownership to nbari/release |
| `docs/rulesets/candidates.json` | A | Move active ownership to nbari/release |
| `docs/rulesets/develop-integrity.json` | A | Move active ownership to nbari/release |
| `docs/rulesets/develop-review.json` | A | Move active ownership to nbari/release |
| `docs/rulesets/main-integrity.json` | A | Move active ownership to nbari/release |
| `docs/rulesets/main-promotion.json` | A | Move active ownership to nbari/release |
| `docs/rulesets/release-tags-create.json` | A | Move active ownership to nbari/release |
| `docs/rulesets/release-tags-immutable.json` | A | Move active ownership to nbari/release |
| `examples/shell/.release-flow.json` | A | Move active ownership to nbari/release |
| `examples/shell/README.md` | A | Move active ownership to nbari/release |
| `examples/shell/VERSION` | A | Move active ownership to nbari/release |
| `examples/shell/app/hello.sh` | A | Move active ownership to nbari/release |
| `examples/shell/tools/adapter.sh` | A | Move active ownership to nbari/release |
| `rust-toolchain.toml` | B | Keep in nbari/release-flow |
| `scripts/action.sh` | A | Move active ownership to nbari/release |
| `scripts/adapters/cargo.sh` | A | Move active ownership to nbari/release |
| `scripts/adapters/release-flow.sh` | C | Retire mixed crate/bundle glue; replace with framework shell self-adapter |
| `scripts/candidate-guard.sh` | A | Move active ownership to nbari/release |
| `scripts/candidate-manifest.sh` | A | Move active ownership to nbari/release |
| `scripts/candidate-targets.sh` | A | Move active ownership to nbari/release |
| `scripts/lib/common.sh` | A | Move active ownership to nbari/release |
| `scripts/lib/github.sh` | A | Move active ownership to nbari/release |
| `scripts/lib/project.sh` | A | Move active ownership to nbari/release |
| `scripts/lib/schema.sh` | A | Move active ownership to nbari/release |
| `scripts/lib/tag.sh` | A | Move active ownership to nbari/release |
| `scripts/pipeline-pin.sh` | A | Move active ownership to nbari/release |
| `scripts/publication/ci-install-oras.sh` | A | Move active ownership to nbari/release |
| `scripts/publication/latest.sh` | A | Move active ownership to nbari/release |
| `scripts/publication/ledger.sh` | A | Move active ownership to nbari/release |
| `scripts/publication/plan.sh` | A | Move active ownership to nbari/release |
| `scripts/publication/publish.sh` | A | Move active ownership to nbari/release |
| `scripts/publication/resolve.sh` | A | Move active ownership to nbari/release |
| `scripts/publishers/crates-io.sh` | A | Move active ownership to nbari/release |
| `scripts/publishers/docs.sh` | A | Move active ownership to nbari/release |
| `scripts/publishers/github-release.sh` | A | Move active ownership to nbari/release |
| `scripts/publishers/helm.sh` | A | Move active ownership to nbari/release |
| `scripts/publishers/oci.sh` | A | Move active ownership to nbari/release |
| `scripts/release-candidates.sh` | A | Move active ownership to nbari/release |
| `scripts/release-deploy.sh` | A | Move active ownership to nbari/release |
| `scripts/release-flow-bundle.sh` | A | Move active ownership to nbari/release |
| `scripts/release-flow-install.sh` | A | Move active ownership to nbari/release |
| `scripts/release-prepare.sh` | A | Move active ownership to nbari/release |
| `scripts/release-promote.sh` | A | Move active ownership to nbari/release |
| `scripts/release-retry.sh` | A | Move active ownership to nbari/release |
| `scripts/release-status.sh` | A | Move active ownership to nbari/release |
| `scripts/storage/backends/fs.sh` | A | Move active ownership to nbari/release |
| `scripts/storage/backends/github.sh` | A | Move active ownership to nbari/release |
| `scripts/storage/backends/s3.sh` | A | Move active ownership to nbari/release |
| `scripts/storage/ci-credentials.sh` | A | Move active ownership to nbari/release |
| `scripts/storage/github-bootstrap.sh` | A | Move active ownership to nbari/release |
| `scripts/storage/storage.sh` | A | Move active ownership to nbari/release |
| `scripts/verify-candidate.sh` | A | Move active ownership to nbari/release |
| `src/bin/release-flow.rs` | B | Keep in nbari/release-flow |
| `src/cli/actions/check.rs` | B | Keep in nbari/release-flow |
| `src/cli/actions/mod.rs` | B | Keep in nbari/release-flow |
| `src/cli/actions/plan.rs` | B | Keep in nbari/release-flow |
| `src/cli/actions/status.rs` | B | Keep in nbari/release-flow |
| `src/cli/commands/mod.rs` | B | Keep in nbari/release-flow |
| `src/cli/dispatch/mod.rs` | B | Keep in nbari/release-flow |
| `src/cli/mod.rs` | B | Keep in nbari/release-flow |
| `src/cli/start.rs` | B | Keep in nbari/release-flow |
| `src/cli/telemetry.rs` | B | Keep in nbari/release-flow |
| `src/lib.rs` | B | Keep in nbari/release-flow |
| `src/release/check.rs` | B | Keep in nbari/release-flow |
| `src/release/mod.rs` | B | Keep in nbari/release-flow |
| `src/release/plan.rs` | B | Keep in nbari/release-flow |
| `src/release/version.rs` | B | Keep in nbari/release-flow |
| `src/repository.rs` | B | Keep in nbari/release-flow |
| `tests/cli_integration.rs` | B | Keep in nbari/release-flow |
| `tests/pipeline/ci-install-just.sh` | A | Move active ownership to nbari/release |
| `tests/pipeline/fixtures/candidate-gh.sh` | A | Move active ownership to nbari/release |
| `tests/pipeline/fixtures/candidate-git.sh` | A | Move active ownership to nbari/release |
| `tests/pipeline/fixtures/git-fault-shim.sh` | A | Move active ownership to nbari/release |
| `tests/pipeline/fixtures/mock-aws.sh` | A | Move active ownership to nbari/release |
| `tests/pipeline/fixtures/mock-cargo.sh` | A | Move active ownership to nbari/release |
| `tests/pipeline/fixtures/mock-gh-storage` | A | Move active ownership to nbari/release |
| `tests/pipeline/fixtures/mock-gh.sh` | A | Move active ownership to nbari/release |
| `tests/pipeline/fixtures/mock-oras.sh` | A | Move active ownership to nbari/release |
| `tests/pipeline/fixtures/stub-adapter.sh` | A | Move active ownership to nbari/release |
| `tests/pipeline/lib-release.sh` | A | Move active ownership to nbari/release |
| `tests/pipeline/lib.sh` | A | Move active ownership to nbari/release |
| `tests/pipeline/live-consumer.sh` | A | Move active ownership to nbari/release |
| `tests/pipeline/live-github-storage.sh` | A | Move active ownership to nbari/release |
| `tests/pipeline/live-rulesets.sh` | A | Move active ownership to nbari/release |
| `tests/pipeline/run.sh` | A | Move active ownership to nbari/release |
| `tests/pipeline/test-action.sh` | A | Move active ownership to nbari/release |
| `tests/pipeline/test-bundle.sh` | C | Replace mixed application tests with standalone shell bundle fixtures |
| `tests/pipeline/test-candidates.sh` | A | Move active ownership to nbari/release |
| `tests/pipeline/test-cargo-adapter.sh` | A | Move active ownership to nbari/release |
| `tests/pipeline/test-deploy.sh` | A | Move active ownership to nbari/release |
| `tests/pipeline/test-github-storage.sh` | A | Move active ownership to nbari/release |
| `tests/pipeline/test-guard.sh` | A | Move active ownership to nbari/release |
| `tests/pipeline/test-integration.sh` | A | Move active ownership to nbari/release |
| `tests/pipeline/test-manifest.sh` | A | Move active ownership to nbari/release |
| `tests/pipeline/test-prepare.sh` | A | Move active ownership to nbari/release |
| `tests/pipeline/test-promote.sh` | A | Move active ownership to nbari/release |
| `tests/pipeline/test-publication-plan.sh` | A | Move active ownership to nbari/release |
| `tests/pipeline/test-publishers.sh` | A | Move active ownership to nbari/release |
| `tests/pipeline/test-reusable.sh` | A | Move active ownership to nbari/release |
| `tests/pipeline/test-storage.sh` | A | Move active ownership to nbari/release |

Additional framework tests: `tests/action_metadata.py` and `tests/requirements.txt`.
The application-specific adapter is replaced by a shell framework adapter;
Cargo support remains an optional adapter with isolated Cargo fixture tests.

Historical objects outside the tracked tree remain only in the original repository:
signed tags `0.1.0` and `0.1.2`, local signed `0.1.1`, immutable GitHub Releases,
retained blobs, candidate branches and the separate `release-flow-storage` branch.
No tag, storage branch or old publication ledger is transplanted.
