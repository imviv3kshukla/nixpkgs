import ./make-test-python.nix ({ lib, ... }:

with lib;

{
  name = "binary-cache";
  meta.maintainers = with maintainers; [ thomasjm ];

  nodes.machine =
    { pkgs, ... }: {
      imports = [ ../modules/installer/cd-dvd/channel.nix ];
      environment.systemPackages = with pkgs; [python3];
      system.extraDependencies = with pkgs; [hello hello.inputDerivation];
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

    # Cache should contain a .narinfo referring to "hello"
    machine.succeed("grep 'StorePath: /nix/store/[[:alnum:]]*-hello-' /tmp/cache/*.narinfo")

    # Nix store ping should work
    machine.succeed("nix store ping --store file:///tmp/cache")

    # Should be able to build hello using the cache
    logs = machine.succeed("nix-build -A hello '<nixpkgs>' --option require-sigs false --option trusted-substituters file:///tmp/cache 2>&1")
    import re
    match = re.match(r"^/nix/store/[a-z0-9]*-hello-.*$", str(logs))
    if not match: raise Exception("Output didn't contain reference to built hello")
  '';
})
