#!/bin/bash -e
ROOT="$(cd `dirname $0`/..; pwd)"
uname -a | grep -iq linux && PLATFORM=linux-`uname -m`
uname -a | grep -iq win && PLATFORM=windows-`uname -m`
[ -z "$PLATFORM" ] && { echo "Could not detect platform"; exit 1; }

usage() {
cat<<EOF
  Store a copy of the wallet software for a particular coin in S3.
  Usage: pack.sh [coin]
  Usage: pack.sh [coin] [root]
EOF
exit 1
}

if [ -z "$1" ]; then
  echo Specify a type of coin
  usage
fi
if [ ! -d "$ROOT"/var/wallet/$PLATFORM/"$1" ]; then
  echo "$1" is not a coin there is a wallet for
  usage
fi
if [ -n "$2" ]; then
  if [ ! -d "$2" ]; then
    echo "$2" is not a directory
    usage
  fi
  ROOT="$2"
fi

# Create an archive
ARCHIVE=release/$PLATFORM/$1.tar.bz2
BUCKET=cryptocoin.crahen.net

echo Creating $PLATFORM archive for "$1" wallet
mkdir -p "$ROOT"/var/$(dirname $ARCHIVE)
tar cjf "$ROOT"/var/$ARCHIVE \
    --exclude=\*backup\* \
    --exclude=\*blocks\* \
    --exclude=\*chainstate\* \
    --exclude=\*database\* \
    --exclude=\*txleveldb\* \
    --exclude=\*snapshot\* \
    --exclude=\*.pid \
    --exclude=\*.dat \
    --exclude=\*.sst \
    --exclude=\*.log \
    -C "$ROOT" \
      var/wallet/$PLATFORM/$1

# Upload the archive
cd "$ROOT"/var
cat<<'EOF'|python - "$BUCKET" $ARCHIVE
import hashlib
import os
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
print 'Using Path: %s' % os.getcwd()
#boto.set_stream_logger('pack')

# Start an upload with 3 retries and exponential backoff.
conn = boto.connect_s3()
k = conn.get_bucket(BUCKET).get_key(FILE)
if not k:
  k = boto.s3.key.Key(conn.get_bucket(BUCKET))
k.key = FILE
timeout = 20
for retry in range(0, 3):
  try:
    if os.path.exists(FILE):
      if k.exists():
        if FINGERPRINT == k.get_metadata('fingerprint'):
          break
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
