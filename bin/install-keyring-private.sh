#!/bin/bash -e
ROOT="$(cd `dirname $0`/..; pwd)"
uname -a | grep -iq linux && PLATFORM=linux-`uname -m`
uname -a | grep -iq win && PLATFORM=windows-`uname -m`
[ -z "$PLATFORM" ] && { echo "Could not detect platform"; exit 1; }

usage() {
cat<<EOF
  Install the privatekeys for a keyring into each corresponding wallet. This will install any sensitive information and give the wallets access to the coins associated with those addresses.

  Usage: install-keyring-private.sh [keyring-name]
  Usage: install-keyring-private.sh --no-ui [keyring-name]
  Usage: install-keyring-private.sh [keyring-name] [root]
  Usage: install-keyring-private.sh --no-ui [keyring-name] [root]
EOF
exit 1
}

NOUI=
if [ "$1" == '--no-ui' ]; then
  NOUI=$1
  shift
fi
if [ -z $1 ]; then
  echo Specify a name for the keyring
  usage
fi
KEYRING="$ROOT"/keyring/$1-keyring.private
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
  COIN=$(echo $ADDRESS | sed -e 's,-.*$,,')
  ADDRESS=$(echo $ADDRESS | sed -e 's,[^=]*=,,')
  read PRIVATEKEY
  PRIVATEKEY=$(echo $PRIVATEKEY | sed -e 's,[^=]*=,,')
  echo Installing $COIN privatekey for $ADDRESS
  "$ROOT"/bin/wallet.sh $NOUI $COIN
  "$ROOT"/bin/client.sh $COIN importprivkey "$PRIVATEKEY" $1
  "$ROOT"/bin/client.sh $COIN setaccount "$ADDRESS" $1
  "$ROOT"/bin/client.sh $COIN stop
  sleep 10
done

# Snapshots created with pack.sh will contain this payout address.
