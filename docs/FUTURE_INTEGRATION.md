# Future Rust consumer integration (not activated)

The repositories build and test independently after migration. A later task may
adopt nbari/release in nbari/release-flow through the public installation path:

1. Select and review a full framework commit SHA, preferably from a validated
   signed framework release. Verify its distribution and bundle provenance.
2. Install its versioned bundle exactly as any external application would.
3. Add a project-owned Cargo adapter and configuration to the Rust repository.
   Pin both thin callers and pipeline.repository/sha to nbari/release at that SHA.
4. Add step validation with nbari/release@FULL_SHA and the two reusable job
   callers. Supply only the consumer's own scoped credentials/environments.
5. Exercise test-only candidates first. Verify consumer source SHA separately
   from trusted workflow/runtime SHA, artifacts, manifests and failure paths.
6. Keep framework and Rust versions/lifecycles independent. No submodule, shared
   source directory, unpublished internal path or privileged access is needed.

This migration does not add those files, make CI depend on the other repository,
or prepare/promote an integration release. Old release-flow tags and storage
records remain owned by the original repository and must never be relabeled as
nbari/release provenance.
