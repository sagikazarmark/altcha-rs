# dioxus-altcha

[![crates.io](https://img.shields.io/crates/v/dioxus-altcha?style=flat-square)](https://crates.io/crates/dioxus-altcha)
[![docs.rs](https://img.shields.io/docsrs/dioxus-altcha?style=flat-square)](https://docs.rs/dioxus-altcha)

**[ALTCHA](https://altcha.org) v2 proof-of-work for [Dioxus](https://dioxuslabs.com): solved in Web Workers on WebCrypto, with a hook and a form field**

The browser solves the challenge in Web Workers, off the main thread, and a hook puts it in a form. The server
issues and verifies with the official [`altcha`](https://crates.io/crates/altcha) crate (re-exported here). The form
value is the one the official widget posts, so any ALTCHA v2 server accepts it.

## Quick Start

```rust,ignore
use dioxus::prelude::*;
use dioxus_altcha::{AltchaField, fetch_challenge, use_altcha};

#[component]
fn Join() -> Element {
    let altcha = use_altcha(|| fetch_challenge("/api/altcha"));

    rsx! {
        form { method: "post", action: "/join",
            input { name: "email" }
            AltchaField { altcha }
            button { disabled: altcha.payload().is_none(), "Join" }
        }
    }
}
```

On the server, [`altcha-server`](https://crates.io/crates/altcha-server) issues signed challenges and redeems each solution once, over
a replay store you provide (a database table; `MemoryStore` for one process):

```rust,ignore
let verifier = altcha_server::Verifier::new(key, 5_000)?; // PBKDF2 iterations per attempt
// GET /api/altcha (or `altcha_server::axum::challenge`, with the `axum` feature):
let challenge = verifier.challenge()?;
// ... and for the posted `altcha` field, after your cheaper checks:
let payload = verifier.redeem(&store, &form.altcha).await?;
```

Or by hand with `altcha`: `create_challenge`, then `decode_payload` and `verify_solution`, then record
`payload.challenge.parameters.nonce` until it expires, and refuse it if it's already there.

## Feature Flags

- `embed-worker` (default): embed the solver and start the workers from a `blob:` URL. Without it, serve `WORKER_JS`
  yourself and set `SolveOptions::worker_url`; the solver isn't in your wasm then.
- `native`: solve natively on threads, for Dioxus desktop and mobile. Off by default, so a liveview server never does
  the work.

## Solving

- **Algorithms:** `PBKDF2/SHA-256|384|512`, and iterated `SHA-*`, which is slow above `cost` 1. Not `SCRYPT` or `ARGON2ID`.
- **Workers:** up to 4. Chromium runs every worker's PBKDF2 on one thread, so on Android more workers don't help;
  Safari and Firefox scale.
- **No workers?** If none can start (a CSP, an odd webview), it solves on the main thread, yielding to the page. It
  loads the solver there as a `<script>` from the workers' URL: under a CSP that also restricts scripts, that needs
  `worker_url` (same-origin), since a `blob:` script is blocked too.
- **Secure context:** WebCrypto needs HTTPS or localhost.
- **CSP:** the workers start from a `blob:` URL (`worker-src blob:`). Otherwise serve `WORKER_JS` as a file and set
  `SolveOptions::worker_url`.
- **The challenge passes through untouched** (`RawChallenge`), so a server on another version still verifies it.

## The hook

`use_altcha_with_options`:

- solves on mount (`Auto::OnMount`) or on demand (`Auto::Off`, with `start()` or `solved().await` on submit);
- solves again when the challenge expires, after `refresh()`, and when the page comes back from the back/forward
  cache;
- renders `Idle` first everywhere, so SSR and hydration match.

## Cloudflare Workers

`altcha`'s `solve_challenge` and `verify_solution` read std clocks, which panic on `wasm32-unknown-unknown`. To
verify on Cloudflare Workers, patch in [altcha-org/altcha-lib-rs#1](https://github.com/altcha-org/altcha-lib-rs/pull/1)
until it's released (see the [repository README](https://github.com/sagikazarmark/altcha-rs/blob/main/README.md#cloudflare-workers)).

## Demo

[`demo`](https://github.com/sagikazarmark/altcha-rs/tree/main/demo) is the whole thing as a Dioxus fullstack app. Server functions issue and verify, and the page
has a difficulty slider, solve-on-load or solve-on-submit, attacks the server refuses, a strict-CSP page and a bench.

## Tests

- `cargo test`: the payload, the hook in a VirtualDom (solving with `native`), and the drift test, which needs node
  18+. The drift test solves challenges from `altcha` with `worker.js` under node and checks them with
  `verify_solution`.
- In browsers:

  ```sh
  CARGO_TARGET_WASM32_UNKNOWN_UNKNOWN_RUNNER=wasm-bindgen-test-runner GECKODRIVER=geckodriver \
    cargo test -p dioxus-altcha --target wasm32-unknown-unknown --test wasm_solve
  ```

  (or `CHROMEDRIVER`, `SAFARIDRIVER`; `just test-browser` sets the runner).

## License

Licensed under either of

- Apache License, Version 2.0 ([LICENSE-APACHE](LICENSE-APACHE) or <https://www.apache.org/licenses/LICENSE-2.0>)
- MIT license ([LICENSE-MIT](LICENSE-MIT) or <https://opensource.org/licenses/MIT>)

at your option.

### Contribution

Unless you explicitly state otherwise, any contribution intentionally submitted
for inclusion in the work by you, as defined in the Apache-2.0 license, shall be
dual licensed as above, without any additional terms or conditions.
