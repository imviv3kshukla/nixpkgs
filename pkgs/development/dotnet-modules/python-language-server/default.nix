{ stdenv
, fetchFromGitHub
, fetchurl
, makeWrapper
, dotnet-sdk_3
, openssl
, patchelf
, Nuget
}:

let deps = import ./deps.nix { inherit fetchurl; };

    version = "2020-04-24";

    # Build the nuget source needed for the later build all by itself
    # since it's a time-consuming step that only depends on ./deps.nix.
    # This makes it easier to experiment with the main build.
    nugetSource = stdenv.mkDerivation {
      pname = "python-language-server-nuget-deps";
      inherit version;

      dontUnpack = true;

      nativeBuildInputs = [ Nuget ];

      buildPhase = ''
        export HOME=$(mktemp -d)

        mkdir -p $out/lib

        # disable default-source so nuget does not try to download from online-repo
        nuget sources Disable -Name "nuget.org"
        # add all dependencies to the source
        for package in ${toString deps}; do
          nuget add $package -Source $out/lib
        done
      '';

      dontInstall = true;
    };

in

stdenv.mkDerivation {
  pname = "python-language-server";
  inherit version;

  src = fetchFromGitHub {
    owner = "microsoft";
    repo = "python-language-server";
    rev = "d480cd12649dcff78ed271c92c274fab60c00f2f";
    sha256 = "0p2sw6w6fymdlxn8r5ndvija2l7rd77f5rddq9n71dxj1nicljh3";
  };

  buildInputs = [dotnet-sdk_3 openssl];

  nativeBuildInputs = [
    Nuget
    makeWrapper
    patchelf
  ];

  buildPhase = ''
    mkdir home
    export HOME=$(mktemp -d)
    export DOTNET_CLI_TELEMETRY_OPTOUT=1
    export DOTNET_SKIP_FIRST_TIME_EXPERIENCE=1

    pushd src
    nuget sources Disable -Name "nuget.org"
    dotnet restore --source ${nugetSource}/lib -r linux-x64
    popd

    pushd src/LanguageServer/Impl
    dotnet publish --no-restore -c Release -r linux-x64
    popd
  '';

  # Note: if you want to try using this with libicu, you can remove the DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=true
  # value below and instead pass "--suffix LD_LIBRARY_PATH : ${icu}/lib" to makeWrapper.

  # However, the language server doesn't load the shared library correctly and crashes immediately,
  # as in issue https://github.com/NixOS/nixpkgs/issues/73810

  # This seems to be a common issue with dotnet applications; see also
  # https://github.com/dotnet/core/issues/2186

  # Not sure why LD_LIBRARY_PATH wasn't working; the dotnet documentation indicates that it should work
  # and strace shows that it at least tries to open the desired libicu file.

  # It would be nice to get libicu integrated because then the application will have better internationalization
  # behavior, as described here:
  # https://github.com/dotnet/runtime/blob/master/docs/design/features/globalization-invariant-mode.md

  installPhase = ''
    mkdir -p $out
    cp -r output/bin/Release/linux-x64/publish $out/lib

    mkdir $out/bin
    makeWrapper $out/lib/Microsoft.Python.LanguageServer $out/bin/python-language-server \
      --set DOTNET_SYSTEM_GLOBALIZATION_INVARIANT true
  '';

  postFixup = ''
    patchelf --set-rpath ${openssl.out}/lib $out/lib/System.Security.Cryptography.Native.OpenSsl.so
  '';

  # If we don't disable stripping, the executable fails to start with an error about being unable
  # to find some of the packaged DLLs.
  dontStrip = true;

  meta = with stdenv.lib; {
    description = "Microsoft Language Server for Python";
    homepage = "https://github.com/microsoft/python-language-server";
    license = licenses.asl20;
    maintainers = with maintainers; [ thomasjm ];
    platforms = [ "x86_64-linux" ];
  };
}
