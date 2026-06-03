# josarv/ocaml

Reproducible OCaml development Docker images, built with love using Nix.

Two variants are available: a lean (relatively speaking) base image for CI and pipeline usage, and a full development image for devcontainers and interactive work.

Nix was particularly helpful as packages are pulled from the nixpkgs binary cache, rather than compiled from source. The images are reproducible and auditable from the repository.

---

## Images

| Tag | Description |
|-----|-------------|
| `latest`, `5.4` | Base - compiler, build tools, opam, C toolchain |
| `latest-dev`, `5.4-dev` | Dev - base + LSP, formatter, utop, odoc |

Version tags reflect the OCaml compiler version. 
If the underlying nixpkgs packages have not changed, no new image is pushed.

## Quick start

```bash
docker pull ghcr.io/josarv/ocaml:latest
docker run --rm -it ghcr.io/josarv/ocaml:latest
```

`opam` is initialised automatically on first container start. The default switch uses the pre-installed system compiler - no compilation step. 

## What's included

### Base (`latest`, `5.4`)

- OCaml 5.4 - compiler and standard library
- dune 3 - build system
- opam 2 - package manager, pre-initialised with an `ocaml-system` switch
- C toolchain - gcc, binutils, make, pkg-config
- Build utilities - git, curl, tar, gzip, bzip2, xz, sed, patch, awk, find, diff
- CA certificates

### Dev (`latest-dev`, `5.4-dev`)

Everything in base, plus:

- `ocaml-lsp-server` - LSP for editor integration
- `ocamlformat` - code formatter
- `utop` - enhanced REPL
- `odoc` - documentation generator

## Devcontainer notes

The container runs as user `ocaml` (uid 1000). On Linux hosts, project directories owned by uid 1000 mount without permission issues.

## Using as a build stage

The entrypoint initialises opam on first interactive container start, but `RUN` instructions in a Dockerfile do not go through the entrypoint.
Instead, initialise opam explicitly, and use `opam exec --` to run tools inside the
switch environment.

Note: `eval $(opam env)` only affects the current shell and has no effect across `RUN` instructions - `opam exec --` is the correct alternative.

```dockerfile
FROM ghcr.io/josarv/ocaml:latest AS builder

RUN opam init --bare --no-setup --disable-sandboxing --yes \
    && opam switch create default ocaml-system \
    && opam option --global depext=false

WORKDIR /app

COPY *.opam .
RUN opam install . --deps-only --yes

COPY . .
RUN opam exec -- dune build

FROM debian:bookworm-slim
COPY --from=builder /app/_build/default/bin/main.exe /usr/local/bin/myapp
CMD ["/usr/local/bin/myapp"]
```

## Building locally

Requires Nix, with flakes enabled.

```bash
nix build .#base --out-link result-base && docker load < result-base
nix build .#dev  --out-link result-dev  && docker load < result-dev
```

## License

[MIT](LICENSE)
