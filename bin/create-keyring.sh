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

PRIVATE="$ROOT"/keyring/$1-keyring.private
PUBLIC="$ROOT"/keyring/$1-keyring.public
touch "$PRIVATE"
touch "$PUBLIC"
cp -Rp "$ROOT"/bin "$TMPDIR"

CLIENT="$TMPDIR"/bin/client.sh
WALLET="$TMPDIR"/bin/wallet.sh
WALLET_ARGS="-listen=0 $WALLET_ARGS"
"$ROOT"/bin/coins.sh all | while read COIN; do

  "$ROOT"/bin/unpack.sh $COIN "$TMPDIR"

  # Generate a wallet and new address
  $WALLET $NOUI "$COIN" $WALLET_ARGS 
  ADDRESS=$("$CLIENT" "$COIN" getaddressesbyaccount '' | sed -ne 's,[^"]*"\([^"]*\)".*,\1,p')
  PRIVATEKEY=$("$CLIENT" "$COIN" dumpprivkey "$ADDRESS" | tr -d '\r')
  "$CLIENT" "$COIN" stop
  sleep 5

  # Add to keyring
  mask=`umask`
  umask 0077
  mv "$PUBLIC"{,.tmp}
  mv "$PRIVATE"{,.tmp}
  grep -v "$COIN" "$PUBLIC".tmp > "$PUBLIC" || true
  grep -v "$COIN" "$PRIVATE".tmp > "$PRIVATE" || true
  echo "$COIN-address=$ADDRESS" >> "$PUBLIC"
  echo "$COIN-address=$ADDRESS" >> "$PRIVATE"
  echo "$COIN-privatekey=$PRIVATEKEY" >> "$PRIVATE"
  umask $mask

  # Clean up temporary wallet
  echo Generated $COIN address "$ADDRESS"
  rm -rf "$TMPDIR"/var/wallet/$PLATFORM/$COIN/ || true

done

echo Cleaning up ephemeral wallets used to generate addresses/keys
sleep 5
rm -rf "$TMPDIR"/var/wallet/$PLATFORM || true


# Upload the archive
ARCHIVE=keyring/$1-keyring.public
BUCKET=cryptocoin.crahen.net
cd "$ROOT"
cat<<'EOF'|python - "$BUCKET" $ARCHIVE
import hashlib
import sys
import time
import boto

BUCKET=sys.argv[1]
FILE=sys.argv[2]

def hashfile(filepath):
    sha1 = hashlib.sha1()
    f = open(filepath, 'rb')
    try:
        sha1.update(f.read())
    finally:
        f.close()
    return sha1.hexdigest()
FINGERPRINT=hashfile(FILE)

# Log the identity the upload is run as
conn = boto.connect_iam()
print 'Using Identity: %s' % conn.get_user().user.arn
#boto.set_stream_logger('create-keyring')

# Start an upload with 3 retries and exponential backoff.
conn = boto.connect_s3()
k = boto.s3.key.Key(conn.get_bucket(BUCKET))
k.key = FILE
timeout = 20
for retry in range(0, 3):
  try:
    print 'Uploading %s/%s %s' % (BUCKET, k.key, FINGERPRINT)
    k.set_metadata('fingerprint', FINGERPRINT)
    k.set_contents_from_filename(FILE, policy='public-read')
    break
  except:
    if retry >= 2:
      raise
    print 'Retrying in %d seconds' % timeout
    time.sleep(timeout)
    timeout = timeout * 2
EOF

cat<<EOF
Created keyring $1

  To install the payout addresses from this keyring into your wallets run: install-payout-addresses.sh $1
  To install the private keys from this keyring into your wallets run: install-keyring.sh $1

After installing the keyring addresses, you should backup keyring/$1 somewhere safe and then remove that directory from the disk.
EOF
