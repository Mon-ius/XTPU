#!/bin/dash

curl -fsSL https://sh.rustup.rs | sh -s -- -y && . "$HOME/.cargo/env"
rustup update nightly && rustup default nightly

# cargo install oha
# oha -z 5m -c 1000000 -q 1000000 --latency-correction --disable-keepalive http://192.168.4.180:10086/v1/ed25519.pub