# List the recipes.
[private]
default:
    @just --list --unsorted

# Run all CI jobs, except msrv and test-browser, which need another toolchain or a browser.
ci: fmt check clippy test doc build deny demo

# Build the workspace.
build:
    cargo build --workspace --all-features --locked

# Check formatting.
fmt:
    cargo fmt --all --check
    cargo fmt --all --check --manifest-path demo/Cargo.toml

# Check the workspace, natively and in the browser.
check:
    cargo hack check --workspace --feature-powerset --all-targets --locked
    cargo hack check --workspace --feature-powerset --all-targets --target wasm32-unknown-unknown --locked

# Check with the minimum supported Rust version: `devenv --profile msrv shell -- just msrv`.
msrv:
    cargo check --workspace --all-features --all-targets --locked
    cargo check --workspace --all-features --all-targets --target wasm32-unknown-unknown --locked

# Run clippy, natively and in the browser.
clippy:
    cargo hack clippy --workspace --each-feature --all-targets --locked -- --deny warnings
    cargo hack clippy --workspace --each-feature --all-targets --target wasm32-unknown-unknown --locked -- --deny warnings

# Run tests.
test:
    cargo hack test --workspace --each-feature --locked

# Run the solver's tests in a browser: set CHROMEDRIVER, GECKODRIVER or SAFARIDRIVER.
[env("CARGO_TARGET_WASM32_UNKNOWN_UNKNOWN_RUNNER", "wasm-bindgen-test-runner")]
test-browser:
    cargo test --package dioxus-altcha --target wasm32-unknown-unknown --test wasm_solve --locked

# Run rustdoc.
[env("RUSTDOCFLAGS", "--deny warnings")]
doc:
    cargo hack doc --workspace --each-feature --no-deps --locked

# Check dependencies for advisories, licenses and sources.
deny:
    cargo deny check

# Run clippy on the demo's client and server.
demo:
    cargo clippy --manifest-path demo/Cargo.toml --features web --target wasm32-unknown-unknown --locked -- --deny warnings
    cargo clippy --manifest-path demo/Cargo.toml --features server --locked -- --deny warnings

# Serve the demo with hot reloading; `devenv up` runs the same in the background.
[working-directory("demo")]
serve:
    dx serve --fullstack \
        @client --platform web --no-default-features --features web \
        @server --platform server --no-default-features --features server
