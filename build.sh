#!/bin/bash

cp ../ember-stylus/target/IVolatilityContract.sol ./src/interfaces/

forge build

# forge build -vvvv --extra-output evm --optimize true --optimizer-runs 1 --no-cache --revert-strings debug --build-info