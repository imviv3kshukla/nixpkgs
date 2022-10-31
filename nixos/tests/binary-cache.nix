import ./make-test-python.nix ({ lib, pkgs, ... }:

with lib;

{
  name = "binary-cache";
  meta.maintainers = with maintainers; [ thomasjm ];

  nodes.machine =
    { ... }: {
      environment.systemPackages = [pkgs.src];
    };

  testScript = ''
    status, stdout = machine.execute("env")
    print("Got env", stdout)

    status, stdout = machine.execute("ls -lh /nix/store")
    print("Got nix store contents", stdout)

    status, stdout = machine.execute("ls -lh /nix/var/nix/profiles")
    print("Got profiles contents", stdout)

    status, stdout = machine.execute("ls -lh /nix/var/nix/profiles/per-user")
    print("Got per-user contents", stdout)

    status, stdout = machine.execute("ls -lh /nix/var/nix/profiles/per-user/root")
    print("Got root contents", stdout)

    status, stdout = machine.execute("ls -lh /nix/var/nix/profiles/per-user/root/channels")
    print("Got channels contents", stdout)

    machine.succeed("nix-build -E 'with import <nixpkgs> {}; mkBinaryCache { rootPaths = [hello]; }' -o /tmp/cache")
    machine.succeed("ls -lh /tmp/cache")
  '';
})
