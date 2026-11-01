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
release was published. The Rust consumer integration remains a later task.

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
