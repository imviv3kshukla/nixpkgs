#!/usr/bin/env bats

function teardown() {
    # TODO: remove test images at the end using tags
    # docker rmi $(docker images --filter=reference="*:docker-test*" -q)
    echo "Teardown not implemented"
}

function loadImage() {
    tar -C $1 --hard-dereference --xform s:'^./':: -c . | pigz -nT | docker load
}

@test "builds a container with bash" {
    nix-build '<nixpkgs>' -A dockerExamples.bash -o bash
    loadImage bash/image

    result=$(docker run -it --rm bash bash -c 'echo -n hi')
    [ "$result" = "hi" ]
}

@test "can layer another image on top" {
    nix-build '<nixpkgs>' -A dockerExamples.bashPlusFile -o bashPlusFile
    loadImage bashPlusFile/image

    result=$(docker run -it --rm bashplusfile bash -c 'echo "hi" > some_file; file some_file')
    [[ $result == *"some_file: ASCII text"* ]]
}

@test "can pull an image from DockerHub" {
    nix-build '<nixpkgs>' -A dockerExamples.nixFromDockerHub -o nixFromDockerHub

    loadImage nixFromDockerHub/image

    docker run --rm nixos/nix:2.2.1 nix-store --version
    docker rmi nixos/nix:2.2.1
}
