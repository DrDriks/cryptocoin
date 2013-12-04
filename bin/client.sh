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
CLIENT=$(find -name ${COIN}d\*)
shift

RETRY=20
while :; do
  [ "$RETRY" -eq 0 ] && break
  RETRY=$(($RETRY-1))
  # Try connecting to the wallet 
  $CLIENT -datadir=data -conf=$COIN.conf getdifficulty | grep -qv error && {
    exec $CLIENT -datadir=data -conf=$COIN.conf "$@"
  }
  sleep 3
done

echo Could not connect to wallet after 1-min
exit 1
