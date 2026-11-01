# Release framework guidelines

This repository owns the language-independent release framework. The Rust CLI
lives separately in nbari/release-flow and is not a build or test dependency.
Use plain imperative commit subjects without conventional prefixes.

The root composite Action performs read-only validation in a step. Reusable
candidate.yml and release.yml own multi-job orchestration. Just/Bash owns local
operations. Consumer adapters implement version, set-version, verify, targets,
inventory and package; keep application behavior out of the generic engine.

Treat repository identity, source SHA, version, signed tag and artifact digest as
immutable. Runtime checkout must equal the called workflow SHA; consumer source
is a separate identity. Require full SHA references and fail closed on missing
provenance, unknown channels or invalid digests. Never move a signed tag, rebuild
a promoted version, execute storage records, or force-push protected branches.

Keep promotion atomic and explicitly authorized. Preserve candidate guards,
manifest verification, immutable retention, CAS writes, lock ownership and
independent publisher recovery. Use existing local or forwarded SSH identities;
a separate deploy key is optional. Candidate builds receive no publisher secrets.
Status and plan never mutate remote refs or create tags.

Work on sandbox and integrate reviewed changes into develop. Main is reserved
for authorized guarded releases. Storage metadata has its own protected history.
Never synchronize the storage branch with application branches.

Run just check and just pipeline-test, metadata tests, shell/YAML/workflow checks
and relevant failure injection before committing. Core tests forbid application
toolchains. Optional Cargo adapter tests build isolated fixtures only. Review
actual final diffs and exact-SHA GitHub results; static tests do not establish
cross-repository execution. Marketplace publication requires a separate owner UI
operation and public listing verification; a GitHub Release alone is insufficient.
