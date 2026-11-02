# External Rust consumer validation

The standalone Rust CLI [nbari/release-flow](https://github.com/nbari/release-flow)
now consumes this framework using the same public bundle installer, full-SHA
Action and reusable workflow interfaces as other projects. Its Rust builds do
not require a framework source checkout. Managed release operations are installed
files, not a separately maintained engine fork.

The consumer owns its Cargo adapter wrapper, native target matrix and package
checks. Its test candidates build 19 artifacts across eight native binary targets
and one source-crate target. GitHub Release is its only enabled publisher;
crates.io publication is a separate authorization.

For each framework release, including the initial GitHub-only 0.1.0:

1. Verify the signed framework tag, immutable release, manifest and bundle source.
2. Upgrade through the public installer. Align the bundle source, Action,
   reusable callers and configuration pipeline SHA to that release's full SHA.
3. Run independent Rust development CI and an explicit sandbox `just deploy-test`.
4. Verify all binary machine types, DEB/RPM metadata, archive inventories,
   source/runtime identities and manifest digests. Test-only candidates cannot
   be promoted and do not establish production retention or publishing success.
5. Exercise a production release only when separately authorized, using the
   original retained candidate bytes and the guarded signed promotion path.

Marketplace publication remains deferred until this validation is complete.
The two repositories retain separate versions and release lifecycles. No
submodules, shared directories or privileged private dependency is required.
Historical release-flow tags and storage retain their original provenance.
