{ stdenv
, fetchFromGitHub
, fetchurl
, makeWrapper
, dotnet-sdk
, dotnet-sdk_3
, mono
, Nuget
}:

let deps = import ./deps.nix { inherit fetchurl; };

in

stdenv.mkDerivation {
  pname = "python-language-server";
  version = "2020-04-17";

  src = fetchFromGitHub {
    owner = "microsoft";
    repo = "python-language-server";
    rev = "c66e4043eabc91121d7c5b7ae80d48b234e6b57a";
    sha256 = "1b40phk5ya7rxkv3gzdlqwn3a41yydb98ibgnljhzban01cnw3zp";
  };

  buildInputs = [Nuget
                 dotnet-sdk_3];

  buildPhase = ''
    mkdir home
    export HOME=$PWD/home
    export DOTNET_CLI_TELEMETRY_OPTOUT=1
    export DOTNET_SKIP_FIRST_TIME_EXPERIENCE=1

    # disable default-source so nuget does not try to download from online-repo
    nuget sources Disable -Name "nuget.org"
    # add all dependencies to a source called 'nixos'
    for package in ${toString deps}; do
      nuget add $package -Source nixos
    done

    pushd src
    dotnet restore --source ../nixos -r linux-x64
    echo "FINISHED RESTORE"
    popd

    pushd src/LanguageServer/Impl
    dotnet build --no-restore -c Release -r linux-x64
    popd
  '';

  installPhase = ''
    mkdir -p $out
    cp -r output $out/lib

    mkdir $out/bin
    cd $out/bin
    ln -s ../lib/bin/Release/Microsoft.Python.LanguageServer ./python-language-server
  '';

  dontStrip = true;

  meta = {
    description = "Microsoft Language Server for Python";
    homepage = "https://github.com/microsoft/python-language-server";
    license = stdenv.lib.licenses.asl20;
    maintainers = with stdenv.lib.maintainers; [ thomasjm ];
    platforms = with stdenv.lib.platforms; linux;
  };
}
