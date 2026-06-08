//! peepee — a minimal PICO forward HTTP proxy built on hyper.
//!
//! This is your starting point — the proxy isn't implemented yet. `hyper` is
//! already wired up as a dependency in Cargo.toml; write the proxy here.
//!
//! A forward proxy needs to handle two things:
//!   1. plain HTTP requests (absolute-form URIs) — forward them upstream and
//!      stream the response back, and
//!   2. `CONNECT host:port` — reply 200, then tunnel raw bytes both ways so
//!      HTTPS flows through without the proxy seeing the plaintext.
//!
//! hyper 1.x is runtime-agnostic, so you'll also want to pull in an async
//! runtime (tokio is the usual choice) before you can accept connections.

fn main() {
    println!("peepee: not implemented yet");
}
