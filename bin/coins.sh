#!/bin/sh -e
ROOT="$(cd `dirname $0`/..; pwd)"
uname -a | grep -iq linux && PLATFORM=linux-`uname -m`
uname -a | grep -iq win && PLATFORM=windows-`uname -m`
[ -z "$PLATFORM" ] && { echo "Could not detect platform"; exit 1; }

usage() {
cat<<EOF
  Usage: coins.sh - print installed coins
  Usage: coins.sh all - print all coins
EOF
exit 1
}

if [ -z "$1" ]; then
  cd "$ROOT"/var/wallet/$PLATFORM/ 
  ls -d1 *
else
cat<<EOF
anoncoin
bitcoin
bbqcoin
digitalcoin
feathercoin
frankocoin
freicoin
galaxycoin
goldcoin
grandcoin
litecoin
megacoin
namecoin
novacoin
orbitcoin
ppcoin
primecoin
stablecoin
tagcoin
terracoin
worldcoin
EOF
fi
