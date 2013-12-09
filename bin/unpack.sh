#!/bin/bash -e
ROOT="$(cd `dirname $0`/..; pwd)"
uname -a | grep -iq linux && PLATFORM=linux-`uname -m`
uname -a | grep -iq win && PLATFORM=windows-`uname -m`
[ -z "$PLATFORM" ] && { echo "Could not detect platform"; exit 1; }

usage() {
cat<<EOF
  Fetch a copy of the wallet software for a particular coin from S3.
  Usage: unpack.sh [coin]
  Usage: unpack.sh [coin] [root]
EOF
exit 1
}

if [ -z "$1" ]; then
  echo Specify a type of coin
  usage
fi
OUT="$ROOT"
if [ -n "$2" ]; then
  if [ ! -d "$2" ]; then
    echo "$2" is not a directory
    usage
  fi
  OUT="$2"
fi

# Download the archive
ARCHIVE=release/$PLATFORM/$1.tar.bz2 
BUCKET=cryptocoin.crahen.net

mkdir -p "$ROOT"/var
mkdir -p var/`dirname $ARCHIVE`
cd "$ROOT"/var
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
if not k:
  k = boto.s3.key.Key(conn.get_bucket(BUCKET))
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
tar xjf $ARCHIVE -C "$OUT"
