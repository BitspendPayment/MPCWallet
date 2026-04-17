{
  description = "Nitro Enclave - reproducible build (Rust)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    flake-utils.url = "github:numtide/flake-utils";
    aws-nitro-util.url = "github:monzo/aws-nitro-util";
  };

  outputs = { self, nixpkgs, flake-utils, aws-nitro-util }:
    flake-utils.lib.eachSystem [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ] (system:
      let
        pkgs = import nixpkgs { inherit system; };
        eifPkgs = if system == "x86_64-linux" then pkgs
                  else import nixpkgs { system = "x86_64-linux"; };
        nitro = aws-nitro-util.lib.x86_64-linux;

        configPath = let p = builtins.getEnv "BUILD_CONFIG_PATH"; in
          if p != "" then p else "./enclave/build-config.json";
        buildCfg = builtins.fromJSON (builtins.readFile configPath);
        appCfg = buildCfg.app;
        sdkCfg = buildCfg.sdk;

        version = buildCfg.version;
        region = buildCfg.region;
        deployment = buildCfg.prefix;

        # Enclave supervisor — built from the SDK repo.
        enclave-supervisor = eifPkgs.buildGoModule {
          pname = "enclave-supervisor";
          version = buildCfg.version;

          src = eifPkgs.fetchFromGitHub {
            owner = "ArkLabsHQ";
            repo = "introspector-enclave";
            rev = sdkCfg.rev;
            hash = sdkCfg.hash;
          };

          sourceRoot = "source/sdk";
          vendorHash = sdkCfg.vendor_hash;
          subPackages = [ "cmd/enclave-supervisor" ];
          env.CGO_ENABLED = "0";
          ldflags = [
            "-X" "github.com/ArkLabsHQ/introspector-enclave/sdk.Version=${version}"
          ];
          buildFlags = [ "-trimpath" ];
          tags = [ "netgo" ];
          doCheck = false;
        };

        # User's Rust app — fetched from GitHub. No SDK dependency needed.
        upstream-app = eifPkgs.rustPlatform.buildRustPackage ({
          pname = appCfg.binary_name;
          version = buildCfg.version;

          src = eifPkgs.fetchFromGitHub {
            owner = appCfg.nix_owner;
            repo = appCfg.nix_repo;
            rev = appCfg.nix_rev;
            hash = appCfg.nix_hash;
          };

          cargoHash = if appCfg.nix_vendor_hash == "" then "" else appCfg.nix_vendor_hash;

          doCheck = false;

          buildNoDefaultFeatures = true;
          buildFeatures = [ "enclave-backend" ];

          nativeBuildInputs = [ eifPkgs.pkg-config eifPkgs.protobuf ];
          buildInputs = [ eifPkgs.openssl ];

          postInstall = ''
            # Rename whatever was built to the configured binary name.
            for f in $out/bin/*; do
              if [ "$(basename "$f")" != "${appCfg.binary_name}" ]; then
                mv "$f" "$out/bin/${appCfg.binary_name}"
              fi
            done
          '';
        } // (if (appCfg.nix_subdir or "") != "" then {
          sourceRoot = "source";
          cargoRoot = appCfg.nix_subdir;
          buildAndTestSubdir = appCfg.nix_subdir;
        } else {}));

        nitriding = eifPkgs.buildGoModule {
          pname = "nitriding-daemon";
          version = "unstable-2024-01-01";

          src = eifPkgs.fetchFromGitHub {
            owner = "brave";
            repo = "nitriding-daemon";
            rev = "c8cb7248843c82a5d72ff6cdde90f4a4cf68c87f";
            hash = "sha256-0ww8ZcoUh3UgRJyhfEVwmjxk3tZv7exCw0VmftdnM7U=";
          };

          vendorHash = "sha256-B/1tbPfId6qgvaMwPF5w4gFkkkeoI+5k+x0jEvJxQus=";

          env.CGO_ENABLED = "0";
          buildFlags = [ "-trimpath" ];
          doCheck = false;

          postInstall = ''
            mv $out/bin/nitriding-daemon $out/bin/nitriding
          '';
        };

        viproxy = eifPkgs.buildGoModule {
          pname = "viproxy";
          version = "0.1.2";

          src = eifPkgs.fetchFromGitHub {
            owner = "brave";
            repo = "viproxy";
            rev = "v0.1.2";
            hash = "sha256-xcQCvl+/d7a3fdqDMEEIyP3c49l1bu7ptCG+RZ94Xws=";
          };

          vendorHash = "sha256-WOzeqHo1cG8USbGUm3OAEUgh3yKTamCaIL3FpsshnjI=";

          subPackages = [ "example" ];
          env.CGO_ENABLED = "0";

          postInstall = ''
            mv $out/bin/example $out/bin/proxy
          '';
        };

        appDir = eifPkgs.runCommand "enclave-app" { } ''
          mkdir -p $out/app/data
          cp ${upstream-app}/bin/${appCfg.binary_name} $out/app/${appCfg.binary_name}
          cp ${enclave-supervisor}/bin/enclave-supervisor $out/app/enclave-supervisor
          cp ${nitriding}/bin/nitriding $out/app/nitriding
          cp ${viproxy}/bin/proxy $out/app/proxy
          install -m 0755 ${./enclave/start.sh} $out/app/start.sh
        '';

        enclaveRootfs = eifPkgs.buildEnv {
          name = "enclave-rootfs";
          paths = [
            appDir
            eifPkgs.busybox
            eifPkgs.cacert
          ];
          pathsToLink = [ "/" ];
        };

        secretsCfgJson = builtins.toJSON (buildCfg.secrets or []);

        enclaveEnv = let
          appEnvLines = builtins.concatStringsSep "\n"
            (builtins.map (k: "${k}=${builtins.getAttr k appCfg.env}")
              (builtins.attrNames appCfg.env));
        in ''
          PATH=/app:/bin:/usr/bin
          SSL_CERT_FILE=/etc/ssl/certs/ca-bundle.crt
          AWS_REGION=${region}
          ENCLAVE_APP_NAME=${buildCfg.name}
          ENCLAVE_SECRETS_CONFIG=${secretsCfgJson}
          ENCLAVE_MIGRATION_COOLDOWN=${buildCfg.migration_cooldown or "0s"}
          ENCLAVE_PREVIOUS_PCR0=${buildCfg.previous_pcr0 or "genesis"}
          ENCLAVE_DEPLOYMENT=${deployment}
          ${appEnvLines}
        '';

        eif = nitro.buildEif {
          name = "${buildCfg.name}-enclave";
          inherit version;

          arch = "x86_64";
          kernel = nitro.blobs.x86_64.kernel;
          kernelConfig = nitro.blobs.x86_64.kernelConfig;
          nsmKo = nitro.blobs.x86_64.nsmKo;

          copyToRoot = enclaveRootfs;
          entrypoint = "/app/start.sh";
          env = enclaveEnv;
        };

        # Vendor hash check — used by enclave setup to discover the correct hash.
        vendor-hash-check = eifPkgs.rustPlatform.buildRustPackage ({
          pname = "vendor-hash-check";
          version = buildCfg.version;
          src = eifPkgs.fetchFromGitHub {
            owner = appCfg.nix_owner;
            repo = appCfg.nix_repo;
            rev = appCfg.nix_rev;
            hash = appCfg.nix_hash;
          };
          cargoHash = "";
          doCheck = false;

          buildNoDefaultFeatures = true;
          buildFeatures = [ "enclave-backend" ];

          nativeBuildInputs = [ eifPkgs.pkg-config eifPkgs.protobuf ];
          buildInputs = [ eifPkgs.openssl ];
        } // (if (appCfg.nix_subdir or "") != "" then {
          sourceRoot = "source";
          cargoRoot = appCfg.nix_subdir;
          buildAndTestSubdir = appCfg.nix_subdir;
        } else {}));

      in
      {
        packages = {
          inherit upstream-app enclave-supervisor nitriding viproxy eif vendor-hash-check;
          default = eif;
        };
      }
    );
}
