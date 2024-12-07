#!/bin/bash

cp -R -f ../ember-brevis/examples/contracts/contracts/ src/brevis

forge build -vvvv --extra-output evm --optimize true --optimizer-runs 1 --no-cache --revert-strings debug --build-info