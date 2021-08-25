{ self, inputs, nixpkgs, system }:

with import (nixpkgs + "/nixos/lib/testing-python.nix") {
  inherit system;
};

makeTest {
  nodes = {
    server = { ... }: {
      imports = [ self.nixosModule ];
    };
  };

  testScript = ''
    start_all()
    server.wait_for_unit("mcfi.service")
    assert "MCFI version" in server.wait_until_succeeds("curl --fail http://localhost:9000/")
  '';
}
