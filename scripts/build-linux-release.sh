#!/bin/sh

ODIN_ROOT=$(pwd)/deps/Odin
$ODIN_ROOT/odin build src/ -out=bidou -o:speed -extra-linker-flags:"-pthread -ldl" -define:GLFW_SHARED=false
