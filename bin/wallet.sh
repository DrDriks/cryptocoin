#!/bin/sh -e
ROOT="$(cd `dirname $0`/..; pwd)"
uname -a | grep -iq linux && PLATFORM=linux-`uname -m`
uname -a | grep -iq win && PLATFORM=windows-`uname -m`
[ -z "$PLATFORM" ] && { echo "Could not detect platform"; exit 1; }

usage() {
cat<<EOF
  Run the wallet software for a particular type of coin.
  Usage: wallet.sh [coin] ...
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
WALLET=$(find -name $COIN-qt\*)
CLIENT=$(find -name ${COIN}d\*)
shift
$WALLET -datadir=data -conf=$COIN.conf "$@" -server -min &
PID=$!

# Ping the wallet before returning to sanity check
RETRY=20
while :; do
  [ "$RETRY" -eq 0 ] && break
  RETRY=$(($RETRY-1))
  $CLIENT -datadir=data -conf=$COIN.conf getdifficulty | grep -qv error && break
done

if [ $RETRY -eq 0 ]; then
  echo Could not connect to wallet after 1-min
  echo kill -9 $PID
  exit 1
fi
