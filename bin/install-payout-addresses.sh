#!/bin/sh -e
ROOT="$(cd `dirname $0`/..; pwd)"
uname -a | grep -iq linux && PLATFORM=linux-`uname -m`
uname -a | grep -iq win && PLATFORM=windows-`uname -m`
[ -z "$PLATFORM" ] && { echo "Could not detect platform"; exit 1; }

usage() {
cat<<EOF
  Install the public addresses from a keyring as payout addresses into each corresponding wallet. This will not install any sensitive information like wallet.dat files or privatekeys, only public addresses.

  Usage: install-payout-addresses.sh [keyring-name]
  Usage: install-payout-addresses.sh [keyring-name] [root]
EOF
exit 1
}


if [ -z $1 ]; then
  echo Specify a name for the keyring
  usage
fi
KEYRING="$ROOT"/keyring/$1.keyring
if [ ! -f "$KEYRING" ]; then
  echo No keyring named $1 exists
  usage
fi
if [ -n "$2" ]; then
  if [ ! -d "$2" ]; then
    echo "$2" is not a directory
    usage
  fi
  ROOT="$2"
fi

# Copy the public address into each wallet
cd "$ROOT"
cat "$KEYRING" | while read ADDRESS; do
  [ $ADDRESS != ${ADDRESS/address/} ] || continue
  COIN=$(echo $ADDRESS | sed -e 's,-.*$,,')
  ADDRESS=$(echo $ADDRESS | sed -e 's,[^=]*=,,')
  echo Installing $COIN payout address $ADDRESS
  mkdir -p var/wallet/$PLATFORM/$COIN
  "$ROOT"/bin/wallet.sh $NOUI $COIN
  "$ROOT"/bin/client.sh $COIN setaccount "$ADDRESS" $1-payout
  "$ROOT"/bin/client.sh $COIN stop
  echo "$ADDRESS" > var/wallet/$PLATFORM/$COIN/payout.txt
done

# Snapshots created with pack.sh will contain this payout address.
