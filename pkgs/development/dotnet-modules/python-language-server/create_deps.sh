
# To use this script, clone the repo and set this variable to the checkout path:
CHECKOUT_PATH=/home/tom/tools/microsoft-python-language-server/

######################################################

SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Generate lockfiles in source checkout
# cd $CHECKOUT_PATH/src
# dotnet nuget locals all --clear
# dotnet restore -v normal --no-cache PLS.sln --use-lock-file -r linux-x64

# Use the lockfiles to make a file with two columns: name and version number
# for all possible package dependencies
cd $SCRIPTDIR
echo "" > all_versions.txt
for lockfile in $(find "$CHECKOUT_PATH" -name packages.lock.json); do
    echo "Processing lockfile $lockfile"
    python ./process_lockfile.py "$lockfile" >> all_versions.txt
done
# Add extra manually added packages
cat ./manual_deps.txt >> all_versions.txt
cat all_versions.txt | sed '/^$/d' | sort | uniq > tmp
mv tmp all_versions.txt

# Retrieve sha256 hashes for each dependency and format fetchNuGet calls into deps.nix
./format-deps.sh all_versions.txt > deps.nix
