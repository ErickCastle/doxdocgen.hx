# syntax=docker/dockerfile:1.7
ARG RUST_VARIANT=1-bookworm
FROM mcr.microsoft.com/devcontainers/rust:${RUST_VARIANT}

# Pinned to a commit, not the branch: tracking `steel-event-system` would make
# the image non-reproducible. Bump deliberately and rebuild.
ARG HELIX_REPO=https://github.com/mattwparas/helix.git
ARG HELIX_REF=5a8635beda77414850a2b9604aa0643e4713db3b

ENV HELIX_SRC=/opt/helix \
    HELIX_RUNTIME=/opt/helix/runtime \
    STEEL_HOME=/opt/steel \
    STEEL_LSP_HOME=/opt/steel/lsp

# `build-essential` supplies both cc and c++, which the tree-sitter grammars need.
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      build-essential \
      ca-certificates \
      curl \
      git \
      pkg-config \
 && rm -rf /var/lib/apt/lists/*

RUN mkdir -p "${HELIX_SRC}" "${STEEL_HOME}" "${STEEL_LSP_HOME}" \
 && chown -R vscode:vscode "${HELIX_SRC}" "${STEEL_HOME}"

USER vscode

RUN git clone --filter=blob:none "${HELIX_REPO}" "${HELIX_SRC}" \
 && git -C "${HELIX_SRC}" checkout --detach "${HELIX_REF}"

WORKDIR ${HELIX_SRC}

# Installs steel-interpreter, steel-language-server, cargo-steel-lib, steel-forge,
# then hx itself with the `steel` feature. Reads rust-toolchain.toml (1.90.0).
RUN cargo xtask steel

# `xtask steel` ignores the exit status of every cargo install it spawns, so a
# failed build would otherwise produce a silently broken image.
RUN command -v hx \
 && command -v steel \
 && command -v forge \
 && command -v steel-language-server

RUN if [ ! -f "${HELIX_RUNTIME}/grammars/cpp.so" ]; then hx --grammar fetch && hx --grammar build; fi \
 && test -f "${HELIX_RUNTIME}/grammars/c.so" \
 && test -f "${HELIX_RUNTIME}/grammars/cpp.so"

WORKDIR /workspaces
