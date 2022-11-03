# pkgs.mkBinaryCache {#sec-pkgs-binary-cache}

`pkgs.mkBinaryCache` is a function for creating Nix flat-file binary caches. Such a cache exists as a directory on disk, and can be used as a Nix substituter by passing `--substituter file:///path/to/cache` to Nix commands.

## Example

The parameters of `mkBinaryCache` with an example value are described below. This derivation will construct a flat-file binary cache containing the closure of `hello`.

```nix
mkBinaryCache {
  rootPaths = [hello];
}
```

- `rootPaths` specifies a list of root derivations. The transitive closure of these derivations will be copied into the cache.
