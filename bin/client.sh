#!/bin/sh -e
ROOT="$(cd `dirname $0`/..; pwd)"
uname -a | grep -iq linux && PLATFORM=linux-`uname -m`
uname -a | grep -iq win && PLATFORM=windows-`uname -m`
[ -z "$PLATFORM" ] && { echo "Could not detect platform"; exit 1; }

usage() {
cat<<EOF
  Send RPCs to the wallet holding a particular type of coin
  Usage: client.sh [coin] ...
EOF
exit 1
}

if [ -z "$1" ]; then
  echo Specify a type of coin
  usage
fi
if [ ! -d "$ROOT"/var/wallet/$PLATFORM/"$1" ]; then
  echo "$1" is not a coin there is a wallet for
  usage
fi
cd "$ROOT"/var/wallet/$PLATFORM/$1

COIN=$1
CLIENT=$(find -name ${COIN}d\* -o -name bitcoind\* | head -n 1)
shift

# Wait for wallet to stop
if [ -z "$2" -a "$1" == stop ]; then
  "$CLIENT" -datadir=data -conf=$COIN.conf stop
  RETRY=30
  while :; do
    [ "$RETRY" -eq 0 ] && break
    RETRY=$(($RETRY-1))
    "$CLIENT" -datadir=data -conf=$COIN.conf getdifficulty 2>&1 | grep -q "couldn't connect" && break
  done
  if [ $RETRY -eq 0 ]; then
    echo Wallet failed to exit
    exit 1
  fi
  sleep 5
else
  exec $CLIENT -datadir=data -conf=$COIN.conf "$@" 
fi
