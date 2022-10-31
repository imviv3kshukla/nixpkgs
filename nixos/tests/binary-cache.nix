import ./make-test-python.nix ({ lib, ... }:

with lib;

{
  name = "binary-cache";
  meta.maintainers = with maintainers; [ thomasjm ];

  nodes.machine =
    { pkgs, ... }: {
      imports = [ ../modules/installer/cd-dvd/channel.nix ];
      environment.systemPackages = [pkgs.hello.inputDerivation];
    };

  testScript = ''
    machine.succeed("nix-build -E 'with import <nixpkgs> {}; mkBinaryCache { rootPaths = [hello]; }' -o /tmp/cache")
    machine.succeed("ls -lh /tmp/cache")

    # TODO: add some assertions about the contents of the cache
  '';
})
