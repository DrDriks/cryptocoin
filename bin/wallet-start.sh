#!/bin/sh -ex
shopt -s extglob

ROOT=$(cd `dirname $0`/..; pwd; cd - 2>&1 > /dev/null)
cd "$ROOT"
./bin/coins.py | while read coin; do
  # Kick-off a re-index of the wallets if they
  # don't start normally.
  ./bin/$coin -reindex -server&
  echo $! > ./var/run/hashcash/$coin/pid
  disown $!
done
