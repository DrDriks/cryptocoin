#!/bin/sh -e
ROOT="$(cd `dirname $0`/..; pwd)"
uname -a | grep -iq linux && PLATFORM=linux-`uname -m`
uname -a | grep -iq win && PLATFORM=windows-`uname -m`
[ -z "$PLATFORM" ] && { echo "Could not detect platform"; exit 1; }

usage() {
cat<<EOF
  Install a master keyring by installing the payout addresses into the wallet for each type of coin.
  Usage: install-keyring.sh [name]
EOF
exit 1
}

if [ -z "$1" ]; then
  echo Specify a name for the keyring
  usage
fi

# Generate wallets
# Install wallet.dat
# Get address
# Destroy wallets

# Iterate through each available wallet
cd "$ROOT"/var/wallet/$PLATFORM/ 
ls -d1 * | while read COIN; do
  echo $COIN
done
