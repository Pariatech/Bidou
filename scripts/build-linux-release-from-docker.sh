#!/bin/sh

docker buildx build -t build-urban-tycoons-linux -f Dockerfile.linux .

docker create --name build-urban-tycoons-linux build-urban-tycoons-linux
docker cp build-urban-tycoons-linux:/game/urban-tycoons ./urban-tycoons
docker rm build-urban-tycoons-linux
