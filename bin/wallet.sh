#!/bin/sh -e
ROOT="$(cd `dirname $0`/..; pwd)"
uname -a | grep -iq linux && PLATFORM=linux-`uname -m`
uname -a | grep -iq win && PLATFORM=windows-`uname -m`
[ -z "$PLATFORM" ] && { echo "Could not detect platform"; exit 1; }


usage() {
cat<<EOF
  Start a wallet server with or without a UI.
  Usage: wallet.sh [coin] ...
  Usage: wallet.sh --no-ui [coin] ...
EOF
exit 1
}

SUFFIX=-qt
if [ "$1" == '--no-ui' ]; then
  SUFFIX=d
  shift
fi
if [ -z "$1" ]; then
  echo Specify a type of coin
  usage
fi
if [ ! -d "$ROOT"/var/wallet/$PLATFORM/"$1" ]; then
  echo "$1" is no wallet at "$ROOT"/var/wallet/$PLATFORM/"$1" 
  usage
fi

cd "$ROOT"/var/wallet/$PLATFORM/$1
COIN=$1
WALLET=$(find -name $COIN${SUFFIX}\*)
CLIENT=$(find -name ${COIN}d\* -o -name bitcoind\* | head -n 1)
shift

if [ -e data/$COIN.pid ]; then
  if [ -e /proc/`cat data/$COIN.pid` ]; then
    echo $COIN wallet daemon already running `cat data/$COIN.pid`
    exit 1
  fi
fi
$WALLET -datadir=data -pid=$COIN.pid -conf=$COIN.conf "$@" -server -min &
PID=$!
echo $PID > data/$COIN.pid 

# Ping the wallet before returning success
RETRY=20
while :; do
  [ "$RETRY" -eq 0 ] && break
  RETRY=$(($RETRY-1))
  $CLIENT -datadir=data -conf=$COIN.conf getbalance 2>&1 | grep -qv "error\|connect" && break
  echo Waiting for $COIN wallet
done

if [ $RETRY -eq 0 ]; then
  echo Could not connect to wallet after 1-min
  echo kill -9 $PID
  exit 1
fi
