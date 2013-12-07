#!/bin/sh -e
ROOT="$(cd `dirname $0`/..; pwd)"
uname -a | grep -iq linux && PLATFORM=linux-`uname -m`
uname -a | grep -iq win && PLATFORM=windows-`uname -m`
[ -z "$PLATFORM" ] && { echo "Could not detect platform"; exit 1; }

usage() {
cat<<EOF
  Usage: snapshot-all.sh 
  Usage: snapshot-all.sh [root]
EOF
exit 1
}

if [ -n "$1" ]; then
  if [ ! -d "$1" ]; then
    echo "$1" is not a directory
    usage
  fi
  ROOT="$1"
fi

echo Creating snapshots of transaction data ...
SLEEP=$((10*6))
"$ROOT"/bin/coins.sh | while read COIN; do
  "$ROOT"/bin/wallet.sh "$COIN" || true
  if [ -n "$SLEEP" ]; then
    echo "Waiting 3-min for wallets to get up to date ..."
    sleep $SLEEP
  fi
  "$ROOT"/bin/client.sh "$COIN" stop || true
  "$ROOT"/bin/snapshot.sh "$COIN"
done
#
