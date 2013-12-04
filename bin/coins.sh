#!/bin/sh -e
ROOT="$(cd `dirname $0`/..; pwd)"
uname -a | grep -iq linux && PLATFORM=linux-`uname -m`
uname -a | grep -iq win && PLATFORM=windows-`uname -m`
[ -z "$PLATFORM" ] && { echo "Could not detect platform"; exit 1; }

usage() {
cat<<EOF
  Print on each line the name of each type of coin that is available.
  Usage: coins.sh
EOF
exit 1
}

cd "$ROOT"/var/wallet/$PLATFORM/ 
ls -d1 *
