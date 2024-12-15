#!/bin/bash

./build.sh

rm -rf src/brevis
mkdir -p src/brevis

cp -R -f ../ember-brevis/examples/contracts/contracts/ src/brevis

rm -rf src/brevis/examples/slot
rm -rf src/brevis/examples/tokenTransfer
rm -rf src/brevis/examples/tradingvolume

forge build -vvvv --extra-output evm --optimize true --optimizer-runs 1 --no-cache --revert-strings debug --build-info