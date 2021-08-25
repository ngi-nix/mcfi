{
  description = "mcfi";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-21.05";
  inputs.pypi-deps-db = {
    url = "github:DavHau/pypi-deps-db";
    flake = false;
  };
  inputs.mach-nix = {
    url = "github:DavHau/mach-nix";
    inputs.nixpkgs.follows = "nixpkgs";
    inputs.pypi-deps-db.follows = "pypi-deps-db";
  };

  inputs.mcfi = {
    url = "git+https://notabug.org/zPlus/mcfi";
    flake = false;
  };

  outputs = { self, mach-nix, mcfi, nixpkgs, ... }:
    let
      version = builtins.substring 0 8 mcfi.lastModifiedDate;
      supportedSystems = [ "x86_64-linux" "x86_64-darwin" ];
      forAllSystems = f: nixpkgs.lib.genAttrs supportedSystems (system: f system);
      nixpkgsFor = forAllSystems (system: import nixpkgs {
        inherit system;
        overlays = [ self.overlay ];
      });
    in
    {
      overlay = final: prev: {
        mcfi = mach-nix.lib.${final.system}.mkPython {
          requirements = builtins.readFile "${mcfi}/requirements.txt";
        };
      };

      devShell = forAllSystems (system: mach-nix.lib.${system}.mkPythonShell {
        requirements = builtins.readFile "${mcfi}/requirements.txt";
      });

      packages = forAllSystems (system: {
        inherit (nixpkgsFor.${system}) mcfi;
      });

      defaultPackage = forAllSystems (system: self.packages.${system}.mcfi);

      checks = forAllSystems (system: {
        inherit (self.packages.${system}) mcfi;
      });
    };
}
