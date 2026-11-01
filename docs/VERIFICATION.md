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
integration is created by the migration. Independent shell GitHub execution and
exact final CI runs will be recorded after the source has been pushed.

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
