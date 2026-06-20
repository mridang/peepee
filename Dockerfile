# syntax=docker/dockerfile:1.7
# The builder always runs on the host's native architecture (BUILDPLATFORM),
# regardless of which TARGETPLATFORM we are producing. cargo-zigbuild then
# cross-compiles to the requested target using Zig as the linker and C
# compiler, so no QEMU emulation is involved — the arm64 image is built at
# native speed on an amd64 host. Base image pinned by digest; the readable
# `1.95-alpine` tag is kept for reviewers.
FROM --platform=$BUILDPLATFORM rust:1.96-alpine@sha256:f87aa870663e2b57ec8c69de82c7eedf7383bee987eef7612c0359635eaadb41 AS builder

# Docker buildx injects TARGETARCH automatically ("amd64" or "arm64").
ARG TARGETARCH

# musl-dev: C headers for the build. upx: final-binary compressor (it is
# architecture-aware and compresses a cross-built binary fine). curl/xz:
# fetch and unpack the Zig toolchain.
RUN apk add --no-cache musl-dev upx curl xz

# Zig doubles as cargo-zigbuild's cross-linker and C compiler, so a single
# toolchain covers every target libc. The tarball is statically linked and
# runs on Alpine/musl. Pinned for reproducibility.
ENV ZIG_VERSION=0.13.0
RUN curl -fsSL "https://ziglang.org/download/${ZIG_VERSION}/zig-linux-x86_64-${ZIG_VERSION}.tar.xz" \
      | tar -xJ -C /usr/local \
 && mv "/usr/local/zig-linux-x86_64-${ZIG_VERSION}" /usr/local/zig
ENV PATH="/usr/local/zig:${PATH}"

# cargo-zigbuild drives cargo with `zig cc` as the linker. Pinned by version so
# the build tool itself never floats — a moving linker driver would defeat the
# byte-identical guarantee.
RUN cargo install cargo-zigbuild --locked --version 0.22.3

# Resolve the Rust target triple from the Docker arch and install it. Both
# targets are musl so the final binary is fully static and runs on scratch.
RUN case "$TARGETARCH" in \
      amd64) echo "x86_64-unknown-linux-musl"  > /rust-target ;; \
      arm64) echo "aarch64-unknown-linux-musl" > /rust-target ;; \
      *) echo "unsupported TARGETARCH: $TARGETARCH" >&2; exit 1 ;; \
    esac \
 && rustup target add "$(cat /rust-target)"

WORKDIR /app
COPY . .

# A fixed SOURCE_DATE_EPOCH (2010-01-01 UTC) removes wall-clock time from any
# build step that honours it, so repeated builds of the same commit are
# bit-for-bit identical. Rust embeds no timestamp, but this also covers UPX and
# any C the musl toolchain compiles.
ENV SOURCE_DATE_EPOCH=1262304000

# Cross-compile, then compress. Symbol stripping is handled by
# `strip = "symbols"` in [profile.release], which the linker applies for the
# correct target arch — a host `strip` would refuse a foreign-arch ELF.
# `upx --no-time` keeps the compressed wrapper free of a build timestamp; with
# the input binary already deterministic, the UPX output is reproducible too.
RUN RUST_TARGET="$(cat /rust-target)" \
 && cargo zigbuild --release --bin peepee --locked --target "$RUST_TARGET" \
 && cp "target/${RUST_TARGET}/release/peepee" /peepee \
 && (upx --lzma --best --no-time /peepee \
       || echo "WARNING: upx compression failed, shipping uncompressed binary")

# Export stage: nothing but the binary. The bake `binaries` target builds this
# with `--output type=local`, dropping the per-arch binary onto the host for
# attachment as GitHub release assets. Never pushed.
FROM scratch AS export
COPY --from=builder /peepee /peepee

# Runtime stage: the published container image. Last stage, so a plain
# `docker build` and the dev bake targets default to it.
FROM scratch AS runtime
# OCI image-spec labels so registries (and downstream scanners) can link the
# image back to its source, license, and project metadata. Keep these in sync
# with the package metadata in Cargo.toml.
LABEL org.opencontainers.image.source="https://github.com/mridang/peepee"
LABEL org.opencontainers.image.url="https://github.com/mridang/peepee"
LABEL org.opencontainers.image.licenses="Apache-2.0"
LABEL org.opencontainers.image.title="peepee"
LABEL org.opencontainers.image.description="A minimal single-file PICO HTTP proxy built on hyper"
COPY --from=builder /peepee /peepee
# Drop root. The scratch image has no /etc/passwd, so we reference the UID:GID
# numerically. 65532 is the conventional non-root UID used by distroless.
USER 65532:65532
ENV PORT=8080
EXPOSE 8080
ENTRYPOINT ["/peepee"]
