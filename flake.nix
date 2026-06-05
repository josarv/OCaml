{
    description = "OCaml development environment Docker image";

    inputs = {
        nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
        flake-utils.url = "github:numtide/flake-utils";
    };

    outputs = { self, nixpkgs, flake-utils }:
        flake-utils.lib.eachSystem
            [ "x86_64-linux" "aarch64-linux" ]
            (system:
        let
            pkgs = import nixpkgs { inherit system; };
            ocamlPkgs = pkgs.ocaml-ng.ocamlPackages_latest;
            version = pkgs.lib.versions.majorMinor ocamlPkgs.ocaml.version;

            baseToolchain = [
                ocamlPkgs.ocaml
                ocamlPkgs.dune_3
                pkgs.opam

                # c toolchain
                pkgs.gcc
                pkgs.binutils
                pkgs.gnumake
                pkgs.pkg-config
                pkgs.m4
                pkgs.glibc
                pkgs.stdenv.cc.cc.lib

                # shell, utilities
                pkgs.bash
                pkgs.coreutils
                pkgs.findutils
                pkgs.diffutils
                pkgs.gawk
                pkgs.gnused
                pkgs.patch
                pkgs.gnugrep

                # network, archives
                pkgs.git
                pkgs.curl
                pkgs.unzip
                pkgs.gnutar
                pkgs.gzip
                pkgs.bzip2
                pkgs.xz
                pkgs.cacert
            ];

            devToolchain = baseToolchain ++ [
                ocamlPkgs.ocaml-lsp
                ocamlPkgs.ocamlformat
                ocamlPkgs.utop
                ocamlPkgs.odoc
            ];

            commonExtraCommands = ''
                mkdir -p ./lib
                mkdir -p ./usr/bin

                ln -s /bin/env ./usr/bin/env

                # VS Code needs glibc and libstdc++ at standard paths.
                # Use explicit Nix store paths — both packages are in the closure
                # so these symlinks will be valid inside the container.
                for f in ${pkgs.glibc}/lib/*; do
                    ln -sf "$f" ./lib/$(basename "$f") 2>/dev/null || true
                done
                for f in ${pkgs.stdenv.cc.cc.lib}/lib/*; do
                    ln -sf "$f" ./lib/$(basename "$f") 2>/dev/null || true
                done

                mkdir -p ./root
                mkdir -p ./tmp
                chmod 1777 ./tmp
                mkdir -p ./workspace
                mkdir -p ./home/ocaml

                echo "root:x:0:0:root:/root:/bin/bash"                         >  ./etc/passwd
                echo "ocaml:x:1000:1000:OCaml Developer:/home/ocaml:/bin/bash" >> ./etc/passwd
                echo "root:x:0:"     >  ./etc/group
                echo "ocaml:x:1000:" >> ./etc/group

                cp ${./entrypoint.sh} ./entrypoint.sh
                chmod +x ./entrypoint.sh
            '';

            commonFakeRootCommands = ''
                chown -R 1000:1000 ./home/ocaml
                chown 1000:1000 ./workspace
            '';

            commonConfig = {
                Entrypoint = [ "/entrypoint.sh" ];
                Cmd = [ "/bin/bash" ];
                User = "ocaml";
                Env = [
                    "PATH=/bin:/usr/bin"
                    "HOME=/home/ocaml"
                    "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
                    "GIT_SSL_CAINFO=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
                    "OPAMNOSANDBOX=1"
                ];
                WorkingDir = "/workspace";
            };

            mkImage = { tag, toolchain }: pkgs.dockerTools.buildLayeredImage {
                name = "ghcr.io/josarv/ocaml";
                inherit tag;
                contents = pkgs.buildEnv {
                    name = "ocaml-dev-env";
                    paths = toolchain;
                    pathsToLink = [ "/bin" "/share" "/etc" ];
                };
                extraCommands = commonExtraCommands;
                fakeRootCommands = commonFakeRootCommands;
                config = commonConfig;
            };

        in
            {
                packages = rec {
                    base = mkImage {
                        tag = version;
                        toolchain = baseToolchain;
                    };
                    dev = mkImage {
                        tag = "${version}-dev";
                        toolchain = devToolchain;
                    };
                    default = dev;
                };
            }
        );
}
