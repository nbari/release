# Branch lifecycle

```mermaid
flowchart TD
    S[sandbox: development] -->|Approved integration| D[develop]
    D -->|Prepare without changing develop| C[release/X.Y.Z-base12: exact candidate commit]
    C -->|Validate and retain bytes| P[Guarded atomic signed promotion]
    P --> M[main = promoted candidate]
    P --> D2[develop = promoted candidate]
    D2 -->|Fast-forward when safe| S2[sandbox]
    STORE[release-flow-storage: isolated metadata history]
```

`main` advances only through authorized release promotion. `develop` accepts
reviewed changes under its ruleset. An explicitly authorized maintainer can
integrate by fast-forward as allowed by repository policy. `sandbox` is not
rewritten by release operations. These branches need not be equal during work;
a successful promotion makes `main` and `develop` equal to the validated candidate.
Fast-forward `sandbox` afterward only if no work would be lost.

Candidate branches are create-only identities with one version bump commit on
the recorded base. Test candidates are `release/test/X.Y.Z-base12` and cannot
be promoted. Fixes belong on the base followed by a fresh candidate. Never
rebase or amend a pushed candidate to repair it.

`release-flow-storage` is an independent protected Git metadata history, never
merged, rebased or synchronized with application branches. Its small records
point at immutable content-addressed retained GitHub assets. Signed version
tags, release artifacts and publication ledger records outlive candidate branches.
See [candidate cleanup](CANDIDATES.md).

The framework's own configuration requests only GitHub Release. Its shell
self-adapter versions VERSION and packages the distribution bundle. Generic
Cargo/crates.io support is optional consumer functionality. This repository
contains no Cargo project or Rust application and never publishes a Rust crate.
The independent Rust CLI retains its own historic versions and release evidence.
