#!/bin/sh -e
ROOT="$(cd `dirname $0`/..; pwd)"
uname -a | grep -iq linux && PLATFORM=linux-`uname -m`
uname -a | grep -iq win && PLATFORM=windows-`uname -m`
[ -z "$PLATFORM" ] && { echo "Could not detect platform"; exit 1; }

usage() {
cat<<EOF
  Create a master keyring that consists of wallets with the private key for the payout address of each type of coin.
  Usage: create-keyring.sh [name]
EOF
exit 1
}

if [ -z "$1" ]; then
  echo Specify a name for the keyring
  usage
fi

TMPDIR=`mktemp -d`
mkdir -p "$TMPDIR"/keyring
cp -Rp "$ROOT"/bin "$TMPDIR"/keyring
"$ROOT"/bin/coins.sh | while read COIN; do
  "$ROOT"/bin/unpack.sh $COIN "$TMPDIR"/keyring
  # Generate a wallet
  "$TMPDIR"/keyring/bin/wallet.sh "$COIN"
  # Extract the address generated with it
  ADDRESS=$("$TMPDIR"/keyring/bin/client.sh "$COIN" getaddressesbyaccount '' | sed -ne 's,[^"]*"\([^"]*\)".*,\1,p')
  "$TMPDIR"/keyring/bin/client.sh "$COIN" stop > /dev/null
  echo "$ADDRESS" > "$TMPDIR"/"$COIN.txt"
  sleep 5
  # TODO wait better
  echo Generated $COIN address "$ADDRESS"
  cp "$TMPDIR"/keyring/var/wallet/$PLATFORM/$COIN/data/wallet.dat "$TMPDIR"/$COIN.dat
  # Destroy the wallet
  rm -rf "$TMPDIR"/keyring/var/wallet/$PLATFORM/$COIN/
done

rm -rf "$TMPDIR"/keyring
mkdir -p "$ROOT"/keyring
tar czf "$ROOT"/keyring/"$1" -C "$TMPDIR" .
