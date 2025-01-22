#!/bin/dash

curl -fsSL https://sh.rustup.rs | sh -s -- -y && . "$HOME/.cargo/env"
rustup update nightly && rustup default nightly
cargo install oha