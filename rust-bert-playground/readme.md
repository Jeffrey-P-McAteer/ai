
# `rust-bert` playground

This folder contains code to build a executable that can scan folders of `.pdf` and `.txt` files for text
and answer questions using the content found within.

The fastest way to get from source to asking questions:
```bash
# Get source code
git clone https://github.com/Jeffrey-P-McAteer/ai.git
cd ai/rust-bert-playground

# Building + running source w/ arguments
cargo build --release -- ./directory/of/documents "What color is the sky?"
```

# Dependencies

 - Rust: [https://www.rust-lang.org/tools/install](https://www.rust-lang.org/tools/install)
    - Even faster, linux and macos: `curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh`
    - Even faster, windorks: [`https://static.rust-lang.org/rustup/dist/x86_64-pc-windows-gnu/rustup-init.exe`](https://static.rust-lang.org/rustup/dist/x86_64-pc-windows-gnu/rustup-init.exe)


# Building

```bash
# For your OS
cargo build --release
# See executable under ./target/release
```

# Running

```bash
# Running a compiled executable w/ arguments
./target/release/rust-bert-playground[.exe] ./directory/of/documents "What color is the sky?"

# Building + running source w/ arguments
cargo run --release -- ./directory/of/documents "What color is the sky?"

# Run HTTP server on port 8080
cargo run --release -- '127.0.0.1:8080'
```

# Misc

 - Swapping BERT (default model) out with any other model supported by the library `rust_bert`: [https://docs.rs/rust-bert/latest/rust_bert/](https://docs.rs/rust-bert/latest/rust_bert/)

 - Model capabilities overview / research: https://towardsdatascience.com/question-answering-with-a-fine-tuned-bert-bc4dafd45626





