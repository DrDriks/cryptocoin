#!/bin/sh -e
ROOT="$(cd `dirname $0`/..; pwd)"
uname -a | grep -iq linux && PLATFORM=linux-`uname -m`
uname -a | grep -iq win && PLATFORM=windows-`uname -m`
[ -z "$PLATFORM" ] && { echo "Could not detect platform"; exit 1; }

usage() {
cat<<EOF
  Install the public addresses from a keyring as payout addresses into each corresponding wallet. This will not install any sensitive information like wallet.dat files or privatekeys, only public addresses.

  Usage: install-keyring-public.sh [keyring-name]
  Usage: install-keyring-public.sh [keyring-name] [root]
EOF
exit 1
}


if [ -z $1 ]; then
  echo Specify a name for the keyring
  usage
fi
KEYRING="$ROOT"/keyring/$1-keyring.public
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

# Download the public keyring
ARCHIVE=keyring/$1-keyring.public
BUCKET=cryptocoin.crahen.net

echo Fetching keyring "$1"
mkdir -p "$ROOT"
mkdir -p `dirname $ARCHIVE`
cd "$ROOT"
cat<<'EOF'|python - "$BUCKET" $ARCHIVE
import hashlib
import os
import sys
import time
import boto

BUCKET=sys.argv[1]
FILE=sys.argv[2]

# Log the identity the upload is run as
conn = boto.connect_iam()
print 'Using Identity: %s' % conn.get_user().user.arn    
print 'Using Path: %s' % os.getcwd()
#boto.set_stream_logger('unpack')

def hashfile(filepath):
    sha1 = hashlib.sha1()
    f = open(filepath, 'rb')
    try:
        sha1.update(f.read())
    finally:
        f.close()
    return sha1.hexdigest()
FINGERPRINT=''
if os.path.exists(FILE):
  FINGERPRINT=hashfile(FILE)

# Start an upload with 3 retries and exponential backoff.
conn = boto.connect_s3()
k = conn.get_bucket(BUCKET).get_key(FILE)
timeout = 20
for retry in range(0, 3):
  try:
    # Stale check
    if os.path.exists(FILE):
      if k.exists():
        if FINGERPRINT == k.get_metadata('fingerprint'):
          break
    # Download
    sys.stdout.write('Downloading %s/%s ' % (BUCKET, k.key))
    k.get_contents_to_filename(FILE)
    print FILE
    FINGERPRINT=hashfile(FILE)
    break
  except:
    if retry >= 2:
      raise
    print 'Retrying in %d seconds' % timeout
    time.sleep(timeout)
    timeout = timeout * 2

# Verify fingerprint
if FINGERPRINT != k.get_metadata('fingerprint'):
  raise Exception("Fingerprint did not match")
EOF

# Copy the public address into each wallet
cd "$ROOT"
cat "$KEYRING" | while read ADDRESS; do
  [ $ADDRESS != ${ADDRESS/address/} ] || continue
  COIN=$(echo $ADDRESS | sed -e 's,-.*$,,')
  ADDRESS=$(echo $ADDRESS | sed -e 's,[^=]*=,,')
  echo Installing $COIN payout address $ADDRESS
  mkdir -p var/wallet/$PLATFORM/$COIN
  "$ROOT"/bin/wallet.sh $NOUI $COIN
  "$ROOT"/bin/client.sh $COIN setaccount "$ADDRESS" $1
  "$ROOT"/bin/client.sh $COIN stop
  sleep 20
done

# Snapshots created with pack.sh will contain this payout address.
