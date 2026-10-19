# demo

dioxus-altcha and altcha-server end to end, as a Dioxus fullstack app: server functions issue and redeem the
challenges, and the browser solves them in Web Workers.

## Structure

| File | Role |
| --- | --- |
| `src/main.rs` | Routes, the layout, and the server's router: the solver at `/altcha-worker.js` and the strict page's CSP |
| `src/server.rs` | Server functions issuing challenges and redeeming solutions with `altcha-server`, each challenge once |
| `src/demo.rs` | The form, its settings, and the attacks the server refuses |
| `src/bench.rs` | Solve and verify timings on the device that opens the page |

## Pages

- **`/`:** a form protected by the proof-of-work.
  - Server functions (`src/server.rs`) issue PBKDF2/SHA-256 challenges and verify the solutions, accepting each
    challenge once by its nonce.
  - The page has a difficulty slider (the server's `cost`).
  - It can solve on load (`Auto::OnMount`) or on submit (`Auto::Off` and `solved().await`).
  - After a join, attack buttons replay or change the accepted payload, and show why the server refuses each.
- **`/strict`:** the same page, served with `Content-Security-Policy: worker-src 'self'`. That restricts workers
  only: a full strict CSP (`script-src 'self'`) would also need allowances for Dioxus's own inline scripts, and would
  block the embedded fallback below, which loads the solver as a `blob:` script.
  - The embedded `blob:` worker is blocked, so the workers load from `/altcha-worker.js`, which the server serves from
    `dioxus_altcha::WORKER_JS` (`SolveOptions::worker_url`).
  - A checkbox uses the embedded worker anyway, to show the fallback to solving on the page.
- **`/bench`:** measurements for whatever device opens it.
  - Use `?costs=1000,5000&workers=1,2,4&runs=30`.
  - It shows the median and p95 solve times, the same challenges solved by `altcha`'s Rust in wasm, and one
    verification's time.
  - Build with `--release`: the Rust-wasm comparison is several times slower in a debug build.

## Prerequisites

The repository's [devenv](https://devenv.sh) shell supplies Rust with the `wasm32-unknown-unknown` target and
Dioxus CLI 0.7.10, the version of `dioxus` in this demo's `Cargo.lock` (`dx` must match it exactly). Without devenv,
install Rust with that target and the CLI yourself:

```sh
rustup target add wasm32-unknown-unknown
cargo install dioxus-cli --version 0.7.10 --locked
```

The demo patches `altcha` with [altcha-org/altcha-lib-rs#1](https://github.com/altcha-org/altcha-lib-rs/pull/1)
(see `Cargo.toml`): the bench solves and verifies with `altcha`'s Rust in the browser, where std clocks panic.

## Run locally

With devenv, from the repository root:

```sh
devenv up                    # a devenv process serving the demo, by default at http://127.0.0.1:8080
devenv shell -- just serve   # or dx in the foreground, with its interactive output
```

Or with `dx` directly:

```sh
cd demo
dx serve --fullstack \
  @client --platform web --no-default-features --features web \
  @server --platform server --no-default-features --features server
```

`dx serve` prints the URL once it's up; add `--release` for the bench's numbers.

- **The server's HMAC key** is random per start, so a restart invalidates the challenges already issued. To keep
  them, export `ALTCHA_DEMO_KEY` before starting (`dx` doesn't read `.env` files).
- **The replay set** is in memory: a real app keeps redeemed nonces in its database until they expire.
- **Phones:** WebCrypto needs HTTPS or localhost, so put a tunnel in front (e.g.
  `cloudflared tunnel --url http://localhost:8080`).

## Build-only checks

```sh
cd demo
cargo clippy --no-default-features --features web --target wasm32-unknown-unknown
cargo clippy --no-default-features --features server
```

`just demo` in the repository root runs the same checks, as CI does.

