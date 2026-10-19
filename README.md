# altcha-rs

[![ci](https://img.shields.io/github/actions/workflow/status/sagikazarmark/altcha-rs/ci.yaml?style=flat-square&label=ci)](https://github.com/sagikazarmark/altcha-rs/actions/workflows/ci.yaml)
[![openssf scorecard](https://api.securityscorecards.dev/projects/github.com/sagikazarmark/altcha-rs/badge?style=flat-square)](https://securityscorecards.dev/viewer/?uri=github.com/sagikazarmark/altcha-rs)

**[ALTCHA](https://altcha.org) v2 proof-of-work for Rust web apps: a server that redeems each solution once, and a Dioxus client that solves in Web Workers**

## Features

- **Compatible with the official widget:** challenges come from the official [`altcha`](https://crates.io/crates/altcha) crate, and the form value is the one the widget posts, so either side works with any ALTCHA v2 counterpart.
- **Each solution once:** the server records every redeemed challenge's signed nonce in a replay store you provide, until the challenge expires.
- **Off the main thread:** the browser solves on WebCrypto in Web Workers, falling back to the main thread when workers can't start.
- **Runs on Cloudflare Workers:** on `wasm32-unknown-unknown`, `altcha-server` reads the clock from `Date.now()` and turns on `altcha`'s `js` feature, which does the same, so Workers servers work as is.

## Crates

| Crate | What it does | |
| --- | --- | --- |
| [`altcha-server`](crates/altcha-server) | Issues signed challenges and redeems each solution once, over a `ReplayStore`; an optional axum challenge handler | [![crates.io](https://img.shields.io/crates/v/altcha-server?style=flat-square)](https://crates.io/crates/altcha-server) [![docs.rs](https://img.shields.io/docsrs/altcha-server?style=flat-square)](https://docs.rs/altcha-server) |
| [`dioxus-altcha`](crates/dioxus-altcha) | Solves challenges in the browser, with a `use_altcha` hook and an `AltchaField` form field | [![crates.io](https://img.shields.io/crates/v/dioxus-altcha?style=flat-square)](https://crates.io/crates/dioxus-altcha) [![docs.rs](https://img.shields.io/docsrs/dioxus-altcha?style=flat-square)](https://docs.rs/dioxus-altcha) |

## Quick start

On the server, issue challenges and redeem the posted solutions (`cargo add altcha-server`):

```rust,ignore
use altcha_server::{MemoryStore, Verifier};

let verifier = Verifier::new(key, 5_000)?; // PBKDF2 iterations per attempt
let store = MemoryStore::default();        // or a database table, as a `ReplayStore`

// GET /api/altcha (or route `altcha_server::axum::challenge` with the `axum` feature):
let challenge = verifier.challenge()?;

// The posted `altcha` field, after your cheaper checks:
let payload = verifier.redeem(&store, &form.altcha).await?;
```

In the browser, solve and post the solution with the form (`cargo add dioxus-altcha`):

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

## Demo

[`demo`](demo) is a Dioxus fullstack app with both sides: server functions issue and redeem, and the pages show
solving on load or on submit, the attacks the server refuses, a strict-CSP page and a benchmark.

Run it from the repository root with [devenv](https://devenv.sh), which has `dx` at the demo's Dioxus version:

```sh
devenv up                    # a devenv process serving the demo, by default at http://127.0.0.1:8080
devenv shell -- just serve   # or dx in the foreground, with its interactive output
```

See the [demo's README](demo/README.md) for running it without devenv, and for its pages.

## Development

The devenv shell has the toolchain, including `dx` and `wasm-bindgen-test-runner` at the locked versions.
CI runs the [just](https://just.systems) recipes:

```sh
just ci                                         # fmt, check, clippy, test, doc, build, package, deny and demo
just test                                       # every feature; the drift test needs node 18+
CHROMEDRIVER=chromedriver just test-browser     # the solver in a browser (or GECKODRIVER, SAFARIDRIVER)
devenv --profile msrv shell -- just msrv        # the minimum supported Rust version
```

## License

Licensed under either of

- Apache License, Version 2.0 ([LICENSE-APACHE](LICENSE-APACHE) or <https://www.apache.org/licenses/LICENSE-2.0>)
- MIT license ([LICENSE-MIT](LICENSE-MIT) or <https://opensource.org/licenses/MIT>)

at your option.

### Contribution

Unless you explicitly state otherwise, any contribution intentionally submitted
for inclusion in the work by you, as defined in the Apache-2.0 license, shall be
dual licensed as above, without any additional terms or conditions.
