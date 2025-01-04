#!/bin/sh

abspath () 
{ 
case "${1}" in 
    [./]*)
    local ABSPATH="$(cd ${1%/*}; pwd)/"
    echo "${ABSPATH/\/\///}"
    ;;
    *)
    echo "${PWD}/"
    ;;
esac
}


CURRENTPATH=`abspath ${0}`
cd $CURRENTPATH

./urban-tycoons
