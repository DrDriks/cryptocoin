#!/bin/sh -e
ROOT="$(cd `dirname $0`/..; pwd)"
uname -a | grep -iq linux && PLATFORM=linux-`uname -m`
uname -a | grep -iq win && PLATFORM=windows-`uname -m`
[ -z "$PLATFORM" ] && { echo "Could not detect platform"; exit 1; }

usage() {
cat<<EOF
  Store a copy of the wallet software for a particular coin in S3.
  Usage: pack-all.sh 
  Usage: pack-all.sh [root]
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

"$ROOT"/bin/coins.sh | while read COIN; do
  "$ROOT"/bin/pack.sh "$COIN"
done
#
