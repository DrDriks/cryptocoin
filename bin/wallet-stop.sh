#!/bin/sh -ex
shopt -s extglob

ROOT=$(cd `dirname $0`/..; pwd; cd - 2>&1 > /dev/null)
cd "$ROOT"
./bin/coins.py | while read coin; do
  F=./var/run/hashcash/$coin/pid
  if [ -e "$F" ]; then
    PID=$(cat ./var/run/hashcash/$coin/pid)
    kill $PID || true
  fi
done
ps auxwww | grep coind | awk '{print $2}'| while read P; do
  kill -9 $P || true
done
