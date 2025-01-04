#!/bin/sh

docker build -t build-bidou-windows -f Dockerfile.windows .

docker run --rm -v $(pwd):/game -w /game build-bidou-windows
