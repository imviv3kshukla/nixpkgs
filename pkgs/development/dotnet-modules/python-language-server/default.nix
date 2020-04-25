{ stdenv
, fetchFromGitHub
, fetchurl
, makeWrapper
, dotnet-sdk_3
, Nuget
}:

let deps = import ./deps.nix { inherit fetchurl; };

    version = "2020-04-17";

    # Build the nuget source needed for the later build all by itself
    # since it's a time-consuming step that only depends on ./deps.nix.
    # This makes it easier to experiment with the main build.
    nugetSource = stdenv.mkDerivation {
      pname = "python-language-server-nuget-deps";
      version = version;

      unpackPhase = "true";

      buildInputs = [Nuget];

      buildPhase = ''
        mkdir home
        export HOME=$PWD/home

        mkdir -p $out/lib

        # disable default-source so nuget does not try to download from online-repo
        nuget sources Disable -Name "nuget.org"
        # add all dependencies to the source
        for package in ${toString deps}; do
          nuget add $package -Source $out/lib
        done
      '';

      installPhase = "true";
    };

in

stdenv.mkDerivation {
  pname = "python-language-server";
  version = version;

  src = fetchFromGitHub {
    owner = "microsoft";
    repo = "python-language-server";
    rev = "c66e4043eabc91121d7c5b7ae80d48b234e6b57a";
    sha256 = "1b40phk5ya7rxkv3gzdlqwn3a41yydb98ibgnljhzban01cnw3zp";
  };

  buildInputs = [
    Nuget
    dotnet-sdk_3
    makeWrapper
  ];

  buildPhase = ''
    mkdir home
    export HOME=$PWD/home
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

  dontStrip = true;

  meta = with stdenv.lib; {
    description = "Microsoft Language Server for Python";
    homepage = "https://github.com/microsoft/python-language-server";
    license = licenses.asl20;
    maintainers = with maintainers; [ thomasjm ];
    platforms = platforms.linux;
  };
}
