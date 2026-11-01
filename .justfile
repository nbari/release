import '.justfiles/deploy.just'

default:
    @just --list

action-metadata-test:
    python3 tests/action_metadata.py

# The core framework suite rejects application toolchain execution.
check: action-metadata-test
    bash tests/without-application-toolchains.sh bash tests/pipeline/run.sh

pipeline-test: action-metadata-test
    bash tests/without-application-toolchains.sh bash tests/pipeline/run.sh

# Optional compatibility tests build only a generated Cargo fixture.
cargo-adapter-test:
    bash tests/adapters/test-cargo.sh

build:
    scripts/adapters/framework.sh package "$(cat VERSION)" dist
