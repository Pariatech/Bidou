#!/bin/sh

ODIN_ROOT=$(pwd)/deps/Odin
$ODIN_ROOT/odin build src/ -out=urban-tycoons -o:speed -extra-linker-flags:"-pthread -ldl" -define:GLFW_SHARED=false
