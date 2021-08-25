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

  outputs = { self, mach-nix, mcfi, nixpkgs, ... } @ inputs:
    let
      version = builtins.substring 0 8 mcfi.lastModifiedDate;
      #supportedSystems = [ "x86_64-linux" "x86_64-darwin" ];
      supportedSystems = [ "x86_64-linux" ];
      forAllSystems = f: nixpkgs.lib.genAttrs supportedSystems (system: f system);
      nixpkgsFor = forAllSystems (system: import nixpkgs {
        inherit system;
        overlays = [ self.overlay ];
      });
    in
    {
      overlay = final: prev: {
        mcfi-env = mach-nix.lib.${final.system}.mkPython {
          requirements = builtins.readFile "${mcfi}/requirements.txt";
        };

        mcfi-post-receive = final.stdenv.mkDerivation {
          pname = "mcfi-post-receive";
          inherit version;

          src = mcfi;

          patchPhase = ''
            sed -ie 's#/opt/mcfi/push.py#${mcfi}/push.py#' ./git-hooks/post-receive
          '';

          nativeBuildInputs = with final; [
            makeWrapper
            python3.pkgs.wrapPython
          ];

          pythonPath = with final.python3.pkgs; requiredPythonModules [
            pygit2
          ];

          installPhase = ''
            buildPythonPath "$out $pythonPath"

            mkdir -p $out/bin
            cp git-hooks/post-receive $out/bin/post-receive
            wrapProgram $out/bin/post-receive \
              --prefix PYTHONPATH : "$program_PYTHONPATH"
          '';
        };
      };

      devShell = forAllSystems (system: mach-nix.lib.${system}.mkPythonShell {
        requirements = builtins.readFile "${mcfi}/requirements.txt";
      });

      packages = forAllSystems (system: {
        inherit (nixpkgsFor.${system})
          mcfi-env
          mcfi-post-receive
          ;
      });

      nixosModule = { pkgs, ... }: {
        nixpkgs.overlays = [ self.overlay ];

        systemd.services.mcfi = {
          wantedBy = [ "multi-user.target" ];
          after = [ "network.target" ];
          description = "MCFI federation server";

          serviceConfig = {
            ExecStart = ''
              ${pkgs.mcfi-env}/bin/gunicorn \
                --name mcfi \
                --log-level info \
                --bind 0.0.0.0:9000 \
                --pythonpath ${mcfi} \
                mcfi:application
              '';

            StateDirectory = "mcfi";
            WorkingDirectory = "/var/lib/mcfi";

            DynamicUser = true;

            Restart = "on-abort";
          };
        };
      };

      checks = forAllSystems (system: 
      with nixpkgsFor.${system};

      {
        inherit (self.packages.${system})
          mcfi-env
          mcfi-post-receive
          ;
      } // lib.optionalAttrs stdenv.isLinux {
        # A VM test of the NixOS module.
        vmTest = import ./test.nix { inherit self inputs nixpkgs system; };
      });
    };
}
