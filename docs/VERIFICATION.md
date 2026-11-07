# Framework migration verification

The source extraction is recorded in [MIGRATION_INVENTORY.md](MIGRATION_INVENTORY.md).
Prototype evidence retains its original identities in
[history/PROTOTYPE_VERIFICATION.md](history/PROTOTYPE_VERIFICATION.md).

The standalone core gate runs with Cargo, rustc, Node and Docker blocked.
Generic Cargo adapter tests are a separate optional fixture suite. No command
builds the release-flow crate or reads the Rust application's source checkout.

Migration validation includes metadata parsing and the strict 125-character
limit, real Action execution, shell adapters, candidate guards, manifests,
GitHub/S3/filesystem contracts, CAS and lock failure injection, signed atomic
promotion guards, independent publisher retries, candidate discovery/pruning,
and reproducible bundle installation and upgrades.

No production release, numeric version tag, Marketplace listing or Rust-consumer
integration is created by the migration. The independent shell and self-candidate
runs below use test-only candidates, which cannot be promoted.

Local migration gates passed all 14 core suites and 1,498 assertions per gate,
plus seven metadata tests. Core tests ran with application tools blocked. The
optional Cargo adapter fixture passed 23 assertions. ShellCheck, actionlint, YAML
validation and whitespace checks passed. The tested framework source snapshot is
`5bc18d5f8e58c6be9f61078eaf3290d1d2357150`; no Rust application is present.

## Actual GitHub migration runs

- [Framework CI, including uses: ./](https://github.com/nbari/release/actions/runs/41294824446): success at `5bc18d5f8e58c6be9f61078eaf3290d1d2357150`.
- [External shell Action](https://github.com/nbari/release-flow-storage-test-20261031/actions/runs/41295305084): success; project `hello`, no adapter execution during validation.
- [External reusable candidate](https://github.com/nbari/release-flow-storage-test-20261031/actions/runs/41295307715): success; consumer source `993d0078a9c38d244d7b8a618619041ff77bedb7`, trusted runtime `nbari/release@5bc18d5f8e58c6be9f61078eaf3290d1d2357150`.

The isolated shell repository is not the release-flow Rust application. Its
candidate mode is test-only, retention was skipped, and no tag or application
release was published. The initial migration kept Rust adoption separate. The Rust consumer has since
adopted the public bundle and reusable workflows; see
[FUTURE_INTEGRATION.md](FUTURE_INTEGRATION.md) for release-by-release validation.

- [Framework CI after adoption pin updates](https://github.com/nbari/release/actions/runs/41295479077): success at `c261a0f0dd5ddff657a3e21680a0f20bb03f913e`.
- [Optional Cargo adapter fixture and core CI](https://github.com/nbari/release/actions/runs/41296643367): success at the same source; the optional fixture does not build the release-flow application.
- [Framework self-candidate](https://github.com/nbari/release/actions/runs/41296660065): success at `5d24c30f0cdfe4526e670c8cd1c2f2ec2d4053fa`, branch `release/test/0.0.1-c261a0f0dd5d`.

The self-candidate ran its shell self-adapter, core verification, bundle packaging,
manifest assembly and independent download verification without a Cargo project.
Its downloaded manifest SHA-256 is
`be1374b3bf1fa15ff469055f2051bad0e8db43fb6570f1609407ddf96e4b55f9`.
The bundle records the exact candidate source and `source_tree_clean: true`.
Retention was skipped as required for test-only candidates. No storage branch
or release from the old repository was copied into this repository.

The independent Rust migration is commit
`58729d30847709553f8e114251adc2256cb812be` in nbari/release-flow. Its
[main CI](https://github.com/nbari/release-flow/actions/runs/41296762574) passed
formatting, Clippy, 27 unit tests, eight CLI integration tests, release build and
CLI smoke checks without this framework. Historical tags, releases, assets and
the storage branch remain in that repository. See [branch lifecycle](BRANCHES.md)
for this framework's default-branch bootstrap policy.

## Initial framework release validation

The first independent framework version is 0.1.0, published on GitHub before
Marketplace activation. Its production candidate must pass exact-SHA validation
and durable retention before signed promotion. Marketplace remains deferred
pending validation of that released SHA through the Rust consumer.

The GitHub publisher has regression coverage for delayed visibility of a newly
created draft, a bounded visibility timeout, and API failure after creation. It
creates a draft once, requests fresh listing responses and waits up to 61 seconds
for draft visibility before any upload. Unknown evidence fails closed; the same
draft remains independently recoverable. An observed conflict is never retried
as absence or used to modify a published release.

## Large-input stream validation

Release readers drain piped input while retaining first-match lookup semantics,
version ordering and strict metadata validation. The large-input regression suite
exercises remote-only tag and branch collisions, protected managed files, active
candidate worktrees, status and promotion across thousands of refs, large tag
bodies, default GPG key selection, archive entry rejection and bundle upgrades.
Transport and GPG failures after valid output remain failures. Rejected operations
preserve protected Git state or publication contents, and recovery reuses retained
artifacts without packaging again or changing the signed tag.

The same regression suite reports 35 failed assertions against the original
`b052911198824598bf38a0b0b1d77748f1024121` source and passes all 72 assertions with
the reader fixes. Both `just check` and `just pipeline-test` pass all 15 core suites
and 1,758 assertions per gate, plus seven metadata tests, with application
toolchains blocked. Evidence comes from
local fixtures using real Git transport and SSH signatures, retained filesystem
artifacts and mocked external destinations.

Bash syntax checks cover all 71 shell scripts. ShellCheck reports no new
diagnostics relative to the original source; its six existing diagnostics are
unchanged. YAML validation passes. Actionlint 1.7.12 passes when its unsupported
`job.workflow_repository`, `job.workflow_ref` and `job.workflow_sha` diagnostics
are filtered; the workflow and Action files are unchanged by this fix.
