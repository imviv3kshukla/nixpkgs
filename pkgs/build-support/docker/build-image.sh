
eval "$initialCommand"

. "$utilSource"

mkdir -p $out
touch baseFiles
touch layer-list
if [[ -n "$fromImage" ]]; then
  if [[ -d "$fromImage" ]]; then
    cat $fromImage/manifest.json  | jq -r '.[0].Layers | .[]' > layer-list

    echo "Linking base image layers ($fromImage)"
    for baseLayer in $(cat layer-list); do
      echo "Got layer: $baseLayer"
      if [[ -n "$(dirname $baseLayer)" ]]; then mkdir -p $out/$(dirname $baseLayer); fi
      ln -s $fromImage/$baseLayer $out/$baseLayer
    done

    cp $fromImage/repositories $out/repositories

    cat $fromImage/manifest.json  | jq -r '.[0].Layers | .[]' > layer-list
    fromImageManifest=$(cat $fromImage/manifest.json)
    fromImageConfig=$(cat $fromImage/$(cat $fromImage/manifest.json | jq -r ".[0].Config"))
  elif [[ -f "$fromImage" ]]; then
    echo "Copying base image layers ($fromImage)"
    mkdir -p from_image_unpacked
    tar -C $out -xpf "$fromImage"

    cat $out/manifest.json  | jq -r '.[0].Layers | .[]' > layer-list
    fromImageManifest=$(cat $out/manifest.json)
    fromImageConfig=$(cat $out/$(cat $out/manifest.json | jq -r ".[0].Config"))

    # Do not import the base image configuration and manifest
    rm -f image/*.json
  else
    echo "Error: fromImage didn't have expected format (should be either unzipped \"image\" folder or \".tar.gz\", was \"$fromImage\")"
    exit 1
  fi

  chmod a+w $out

  if [[ -z "$fromImageName" ]]; then fromImageName=$(jshon -k < $out/repositories|head -n1); fi
  if [[ -z "$fromImageTag" ]]; then fromImageTag=$(jshon -e $fromImageName -k < $out/repositories | head -n1); fi
  parentID=$(jshon -e $fromImageName -e $fromImageTag -u < $out/repositories)

  echo "Gathering base files"
  for l in $out/*/layer.tar; do
    ls_tar $l >> baseFiles
  done
fi

chmod -R ug+rw $out

mkdir temp
cp ${layer}/* temp/
chmod ug+w temp/*

for dep in $(cat $layerClosure); do
  find $dep >> layerFiles
done

# Record the contents of the tarball with ls_tar.
ls_tar temp/layer.tar >> baseFiles

# Append nix/store directory to the layer so that when the layer is loaded in the
# image /nix/store has read permissions for non-root users.
# nix/store is added only if the layer has /nix/store paths in it.
if [ $(wc -l < $layerClosure) -gt 1 ] && [ $(grep -c -e "^/nix/store$" baseFiles) -eq 0 ]; then
  mkdir -p nix/store
  chmod -R 555 nix
  echo "./nix" >> layerFiles
  echo "./nix/store" >> layerFiles
fi

# Get the files in the new layer which were *not* present in
# the old layer, and record them as newFiles.
comm <(sort -n baseFiles|uniq) \
     <(sort -n layerFiles|uniq|grep -v ${layer}) -1 -3 > newFiles
# Append the new files to the layer.
tar -rpf temp/layer.tar --hard-dereference --sort=name --mtime="@$SOURCE_DATE_EPOCH" \
    --owner=0 --group=0 --no-recursion --files-from newFiles

echo "Adding meta..."

# If we have a parentID, add it to the json metadata.
if [[ -n "$parentID" ]]; then
  cat temp/json | jshon -s "$parentID" -i parent > tmpjson
  mv tmpjson temp/json
fi

# Take the sha256 sum of the generated json and use it as the layer ID.
# Compute the size and add it to the json under the 'Size' field.
layerID=$(sha256sum temp/json|cut -d ' ' -f 1)
size=$(stat --printf="%s" temp/layer.tar)
cat temp/json | jshon -s "$layerID" -i id -n $size -i Size > tmpjson
mv tmpjson temp/json

# Use the temp folder we've been working on to create a new image.
mv temp $out/$layerID

# Add the new layer ID to the beginning of the layer list
(
  # originally this used `sed -i "1i$layerID" layer-list`, but
  # would fail if layer-list was completely empty.
  echo "$layerID/layer.tar"
  cat layer-list
) | sponge layer-list

# Create image json and image manifest
if [[ -n "$fromImage" ]]; then
  imageJson=$fromImageConfig
  baseJsonContents=$(cat $baseJson)

  # Merge the config specified for this layer with the config from the base image.

  # For Env variables, we append them to the base image
  newEnv=$(echo "$baseJsonContents" | jq ".config.Env")
  if [[ -n "$newEnv" && ("$newEnv" != "null") ]]; then
    imageJson=$(echo "$imageJson" | jq ".config.Env |= . + ${newEnv}")
  fi

  # Volumes likewise get added to existing volumes
  newVolumes=$(echo $baseJsonContents | jq ".config.Volumes")
  if [[ -n "$newVolumes" && ("$newVolumes" != "null") ]]; then
    imageJson=$(echo "$imageJson" | jq ".config.Volumes |= . + ${newVolumes}")
  fi

  # All other values overwrite the ones from the base config
  remainingBaseConfig=$(echo "$baseJsonContents" | jq ".config | del(.Env) | del(.Volumes)")
  if [[ -n "$remainingBaseConfig" && ("$remainingBaseConfig" != "null")]]; then
    imageJson=$(echo "$imageJson" | jq ".config |= . + ${remainingBaseConfig}")
  fi

  manifestJson=$(echo "$fromImageManifest" | jq ".[0] |= . + {\"RepoTags\":[\"$imageName:$imageTag\"]}")
else
  imageJson=$(cat ${baseJson} | jq ". + {\"rootfs\": {\"diff_ids\": [], \"type\": \"layers\"}}")
  manifestJson=$(jq -n "[{\"RepoTags\":[\"$imageName:$imageTag\"]}]")
fi

# Add a history item and new layer checksum to the image json
imageJson=$(echo "$imageJson" | jq ".history |= [{\"created\": \"$(jq -r .created ${baseJson})\", \"created_by\": \"$imageName:$imageTag\"}] + .")
newLayerChecksum=$(sha256sum $out/$layerID/layer.tar | cut -d ' ' -f1)
imageJson=$(echo "$imageJson" | jq ".rootfs.diff_ids |= [\"sha256:$newLayerChecksum\"] + .")

# Add the new layer to the image manifest
manifestJson=$(echo "$manifestJson" | jq ".[0].Layers |= [\"$layerID/layer.tar\"] + .")

# Compute the checksum of the config and save it, and also put it in the manifest
imageJsonChecksum=$(echo "$imageJson" | sha256sum | cut -d ' ' -f1)
echo "$imageJson" > "$out/$imageJsonChecksum.json"
manifestJson=$(echo "$manifestJson" | jq ".[0].Config = \"$imageJsonChecksum.json\"")
echo "$manifestJson" > $out/manifest.json

# Store the json under the name image/repositories.
jshon -n object \
      -n object -s "$layerID" -i "$imageTag" \
      -i "$imageName" > $out/repositories

# Make the image read-only.
chmod -R a-w $out

echo "Finished."
