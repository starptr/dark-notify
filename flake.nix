{
  inputs = {
    nixpkgs.url = "github:cachix/devenv-nixpkgs/rolling";
    systems.url = "github:nix-systems/default-darwin";
    devenv.url = "github:cachix/devenv";
    devenv.inputs.nixpkgs.follows = "nixpkgs";
    fenix.url = "github:nix-community/fenix";
    fenix.inputs = {
      nixpkgs.follows = "nixpkgs";
    };
    flake-compat.url = "https://flakehub.com/f/edolstra/flake-compat/1.tar.gz";
    cardboard.url = "github:starptr/cardboard";
  };

  nixConfig = {
    extra-trusted-public-keys = "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw=";
    extra-substituters = "https://devenv.cachix.org";
  };

  outputs =
    {
      self,
      nixpkgs,
      devenv,
      systems,
      cardboard,
      ...
    }@inputs:
    let
      forEachSystem = nixpkgs.lib.genAttrs (import systems);
      metadata = builtins.fromTOML (builtins.readFile ./app/Cargo.toml);
      pname = metadata.package.name;
      version = metadata.package.version;
    in
    {
      packages = forEachSystem (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
        in
        {
          devenv-up = self.devShells.${system}.default.config.procfileScript;
          devenv-test = self.devShells.${system}.default.config.test;
          ${pname} = cardboard.lib.keepFnInput pkgs.rustPackages.rustPlatform.buildRustPackage {
            inherit pname version;
            src = ./app;
            buildInputs = [ pkgs.darwin.apple_sdk.frameworks.AppKit ];
            cargoLock = {
              lockFile = ./app/Cargo.lock;
            };
          };
          default = self.packages.${system}.${pname};
        }
      );

      devShells = forEachSystem (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = devenv.lib.mkShell {
            inherit inputs pkgs;
            modules = [
              {
                # https://devenv.sh/reference/options/
                packages = [
                  pkgs.hello
                  pkgs.darwin.apple_sdk.frameworks.AppKit
                ];

                enterShell = ''
                  hello
                '';

                languages.rust = {
                  enable = true;
                };
              }
            ];
          };
        }
      );

      overlays = {
        ${pname} = final: prev: {
          ${pname} = self.packages.${final.stdenv.hostPlatform.system}.${pname};
        };
        default = self.overlays.${pname};
      };

      formatter = forEachSystem (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
        in
        pkgs.nixfmt-rfc-style
      );
    };
}
