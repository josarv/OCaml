#!/bin/env bash

set -e

if [ ! -d "$HOME/.opam" ]; then
    echo "Initialising opam..."
    opam init --bare --no-setup --disable-sandboxing --yes
    opam switch create default ocaml-system
    opam option --global depext=false
fi

eval $(opam env)
exec "$@"
