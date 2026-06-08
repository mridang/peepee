# Contributing to peepee

Thanks for taking the time to look. peepee is a tiny project — a minimal
forward HTTP proxy — and the bar for contributions is "the change is
correct, the change is tested, and the test suite stays green".

## Quickstart

A reproducible toolchain is pinned via [devbox](https://www.jetify.com/devbox).
Drop into the dev shell, then run the full test and lint gate:

```sh
devbox shell
cargo test --workspace
cargo clippy --all-targets -- -D warnings
cargo fmt --all
```

If you don't use devbox, the toolchain is pinned in `rust-toolchain.toml`
(currently Rust 1.95). The MSRV floor declared in `Cargo.toml` is 1.75 —
bump it only after verifying the new floor against the direct dependency
set (today that is just `hyper`).

If your dev environment needs a custom linker (cross-compilation,
non-system clang, mold/lld, etc.), override it via `~/.cargo/config.toml`
rather than the in-repo `.cargo/config.toml`; the in-repo file is kept
free of host-specific paths so checkouts work for everyone.

> **macOS + nix gotcha:** if a build fails with `can't find crate for`
> a proc-macro crate (e.g. `tokio_macros`), your `cc` is resolving to a
> nix clang wrapper that emits proc-macro dylibs without an `LC_UUID`
> load command, which dyld refuses to `dlopen`. Force Apple's linker:
> `RUSTFLAGS="-C linker=/usr/bin/cc" cargo build`.

## Security advisories

The audit job reads advisory ignores from `.cargo/audit.toml`. peepee
currently ignores nothing — the file holds an empty `ignore` list. If a
transitive advisory ever has to be accepted in-band, add the RUSTSEC id
there with a comment explaining why, rather than masking it silently.

## Project layout

```
crates/
  peepee/   The proxy. A single binary crate built on hyper: HTTP
            CONNECT tunnelling plus plain-HTTP forwarding, with the
            listen port read from the PORT environment variable.
```

`Cargo.toml` declares a virtual workspace; the single member crate has
its own manifest and version, with shared metadata inherited from
`[workspace.package]`. The workspace is set up so additional crates
(say, splitting out a reusable core) can be added under `crates/` later
without restructuring.

## Running tests

```sh
cargo test --workspace        # the default gate
cargo test -p peepee          # the proxy crate only
```

## Where things live

- **Proxy logic** lives in `crates/peepee/src/main.rs`: the accept loop,
  the per-connection service, the CONNECT tunnel, and the plain-HTTP
  forward path.
- **New behaviour** (new methods handled, header rewriting, timeouts)
  belongs alongside the relevant handler in that file, with a test that
  exercises it over a real loopback connection.
- **Configuration** is intentionally minimal — a single `PORT` env var.
  Document any new knob in `README.md` before adding it.

## Commit messages

This repo uses [Conventional Commits](https://www.conventionalcommits.org/).
Keep the subject line under 72 characters, written in the imperative
mood, and prefixed by the change type:

```
feat(proxy): forward Proxy-Authorization on CONNECT
fix(proxy): close the upstream socket when the client hangs up
docs(readme): document the PORT environment variable
refactor(proxy): extract the tunnel splice into its own function
test(proxy): cover the absolute-form to origin-form rewrite
chore(deps): bump hyper to 1.6
```

The body, if present, should explain the "why" rather than restate the
diff. Reference issues with `Closes #N` / `Refs #N` in a trailer.

## Pull requests

- One logical change per PR. If you find an unrelated issue while
  working on a fix, file it separately rather than folding it in.
- `cargo test --workspace` and `cargo clippy --all-targets -- -D warnings`
  must pass. CI runs both.
- Update `README.md` if you change the proxy's observable behaviour or
  its configuration.
