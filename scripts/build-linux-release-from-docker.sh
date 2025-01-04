#!/bin/sh

docker buildx build -t build-bidou-linux -f Dockerfile.linux .

docker create --name build-bidou-linux build-bidou-linux
docker cp build-bidou-linux:/game/bidou ./bidou
docker rm build-bidou-linux
