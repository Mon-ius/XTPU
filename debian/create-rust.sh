#!/bin/dash

curl -fsSL https://sh.rustup.rs | sh -s -- -y && . "$HOME/.cargo/env"
rustup update nightly && rustup default nightly

# cargo install oha
# host=http://127.0.0.1:10086/v1/ed25519.pub
# oha -z 1h -c 100000000 -q 10000000 --latency-correction --disable-keepalive $host