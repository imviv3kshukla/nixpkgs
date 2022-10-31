import ./make-test-python.nix ({ lib, ... }:

with lib;

{
  name = "binary-cache";
  meta.maintainers = with maintainers; [ thomasjm ];

  nodes.machine =
    { pkgs, ... }: {
      imports = [ ../modules/installer/cd-dvd/channel.nix ];
      environment.systemPackages = with pkgs; [hello python3];
      system.extraDependencies = with pkgs; [hello.inputDerivation];
      nix.extraOptions = ''
        experimental-features = nix-command
      '';
    };

  testScript = ''
    machine.succeed("nix-build -E 'with import <nixpkgs> {}; mkBinaryCache { rootPaths = [hello]; }' -o /tmp/cache")

    # Sanity test of cache structure
    status, stdout = machine.execute("ls /tmp/cache")
    cache_files = stdout.split()
    assert ("nix-cache-info" in cache_files)
    assert ("nar" in cache_files)

    # Nix store ping should work
    machine.succeed("nix store ping --store file:///tmp/cache")
  '';
})
