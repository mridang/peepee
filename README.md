# peepee

A minimal **PICO** forward HTTP proxy built on [hyper](https://hyper.rs) 1.x.
The entire proxy is a single file, [`src/main.rs`](src/main.rs).

> **Status: scaffold.** The build, toolchain, reproducibility, and CI setup are
> in place and verified, but the proxy itself is **not implemented yet** —
> [`src/main.rs`](src/main.rs) is a starting stub. `hyper` is the only
> dependency; you add the runtime and write the proxy. The "Usage" section below
> describes the intended behaviour, i.e. what you're building toward.

It should do the two things a forward proxy actually needs:

- **`CONNECT host:port`** — opens a raw TCP tunnel and copies bytes in both
  directions. This is how HTTPS (and any other TLS/opaque protocol) flows
  through the proxy; peepee never sees the plaintext.
- **Plain HTTP** (`GET http://host/path`, …) — forwards the request to the
  origin server in origin-form and streams the response straight back.

Logging is deliberately minimal: one line per accepted request on stderr.

## Usage

The only configuration is the listen port. Resolution order is **CLI argument →
`PORT` env var → `8080`**. peepee always binds `0.0.0.0`.

```sh
peepee            # listen on 0.0.0.0:8080
peepee 3128       # listen on 0.0.0.0:3128
PORT=3128 peepee  # same, via env

# point a client at it
curl -x http://localhost:8080 http://example.com        # plain HTTP
curl -x http://localhost:8080 https://example.com       # HTTPS via CONNECT
```

### Container

The published image is `FROM scratch` (just the static musl binary, non-root):

```sh
docker run --rm -p 8080:8080 mridang/peepee
```

## Building

Local development uses [devbox](https://www.jetify.com/devbox):

```sh
devbox run build    # release build for x86_64-unknown-linux-musl
devbox run lint     # clippy -D warnings
devbox run test
devbox run start    # cargo run
```

> **Note for macOS (Apple Silicon) hosts:** the current dependency graph has no
> proc-macro crates, so native `cargo build` in devbox works fine. The moment
> you add one — e.g. tokio's `macros` feature for `#[tokio::main]`, which pulls
> `tokio-macros` — host-native builds will fail with
> `E0463: can't find crate for tokio_macros`: nix's `libiconv` gets linked into
> proc-macro dylibs and the official rust-lang `rustc` can't dlopen them. It
> only affects native macOS compiles; the musl cross-build and the Docker/CI
> builds (Linux) are unaffected. If you hit it, build via Docker (below), or
> avoid the `macros` feature and build the runtime by hand
> (`tokio::runtime::Builder`).

### Reproducible, multi-arch builds

Release artifacts are built with [`cargo-zigbuild`](https://github.com/rust-cross/cargo-zigbuild)
inside [`Dockerfile`](Dockerfile), driven by [`docker-bake.hcl`](docker-bake.hcl).
The builder runs on the host's native architecture and cross-compiles to each
target with Zig as the linker — no QEMU, so the arm64 image builds at native
speed on an amd64 host.

```sh
docker buildx bake local      # native arch, load into local docker
docker buildx bake amd64      # linux/amd64 image
docker buildx bake arm64      # linux/arm64 image
docker buildx bake binaries   # both arches, export bare binaries to ./dist
docker buildx bake            # both arches → OCI tarball in ./dist
```

Builds are engineered to be **byte-identical** on repeat:

- the toolchain is pinned ([`rust-toolchain.toml`](rust-toolchain.toml) `1.95.0`,
  matching the `rust:1.95-alpine` base image, itself pinned by digest);
- `cargo-zigbuild` and Zig are pinned to exact versions;
- `--locked` everywhere, with `Cargo.lock` committed;
- `--remap-path-prefix` strips host-specific paths (source dir *and* cargo
  registry) out of the binary;
- `[profile.release]` sets `codegen-units = 1`, `lto = "fat"`, `strip`;
- `SOURCE_DATE_EPOCH` is fixed and UPX runs with `--no-time`.

## License

Apache-2.0
