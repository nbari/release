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
