#!/bin/bash -e
ROOT="$(cd `dirname $0`/..; pwd)"
uname -a | grep -iq linux && PLATFORM=linux-`uname -m`
uname -a | grep -iq win && PLATFORM=windows-`uname -m`
[ -z "$PLATFORM" ] && { echo "Could not detect platform"; exit 1; }

usage() {
cat<<EOF
  Unpack all of the wallets.
  Usage: unpack-all.sh 
  Usage: unpack-all.sh [root]
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

"$ROOT"/bin/coins.sh all | while read COIN; do
  "$ROOT"/bin/unpack.sh "$COIN"
done
#
