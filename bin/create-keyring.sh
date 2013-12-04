#!/bin/sh -e
ROOT="$(cd `dirname $0`/..; pwd)"
uname -a | grep -iq linux && PLATFORM=linux-`uname -m`
uname -a | grep -iq win && PLATFORM=windows-`uname -m`
[ -z "$PLATFORM" ] && { echo "Could not detect platform"; exit 1; }


usage() {
cat<<EOF
  A keyring is a set of cryptocoin address/privatekey tuples that give you control of a set of addresses.
  Create a new named keyring will be constructed in your keyring directory, this is very sensitive data.

  Usage: create-keyring.sh [keyring-name]
EOF
exit 1
}


NOUI=
if [ "$1" == '--no-ui' ]; then
  NOUI=$1
  shift
fi
if [ -z "$1" ]; then
  echo Specify a name for the keyring
  usage
fi


TMPDIR=`mktemp -d`
mkdir -p "$TMPDIR"
mkdir -p "$ROOT"/keyring

KEYRING="$ROOT"/keyring/$1.keyring
touch "$KEYRING"
cp -Rp "$ROOT"/bin "$TMPDIR"

CLIENT="$TMPDIR"/bin/client.sh
WALLET="$TMPDIR"/bin/wallet.sh
WALLET_ARGS="-listen=0 $WALLET_ARGS"
"$ROOT"/bin/coins.sh | while read COIN; do

  "$ROOT"/bin/unpack.sh $COIN "$TMPDIR"

  # Generate a wallet and new address
  $WALLET $NOUI "$COIN" $WALLET_ARGS 
  ADDRESS=$("$CLIENT" "$COIN" getaddressesbyaccount '' | sed -ne 's,[^"]*"\([^"]*\)".*,\1,p')
  PRIVATEKEY=$("$CLIENT" "$COIN" dumpprivkey "$ADDRESS" | tr -d '\r')
  #"$CLIENT" "$COIN" backupwallet "${KEYRING/.keyring/.$COIN-wallet.dat}"
  "$CLIENT" "$COIN" stop
  sleep 5

  # Add to keyring
  mask=`umask`
  umask 0077
  mv "$KEYRING"{,.tmp}
  grep -v "$COIN" "$KEYRING".tmp > "$KEYRING" || true
  echo "$COIN-address=$ADDRESS" >> "$KEYRING"
  echo "$COIN-privatekey=$PRIVATEKEY" >> "$KEYRING"
  cp --no-preserve=mode "$TMPDIR"/var/wallet/$PLATFORM/$COIN/data/wallet.dat "${KEYRING/.keyring/.$COIN-wallet.dat}"
  umask $mask

  # Clean up temporary wallet
  echo Generated $COIN address "$ADDRESS"
  rm -rf "$TMPDIR"/var/wallet/$PLATFORM/$COIN/
  rm -f "$KEYRING.tmp"

done

cat<<EOF
Created keyring $1

  To install the payout addresses from this keyring into your wallets run: install-payout-addresses.sh $1
  To install the private keys from this keyring into your wallets run: install-keyring.sh $1

After installing the keyring addresses, you should backup keyring/$1 somewhere safe and then remove that directory from the disk.
EOF
