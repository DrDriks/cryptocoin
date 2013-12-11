#!/bin/bash -e
ROOT="$(cd `dirname $0`/..; pwd)"
uname -a | grep -iq linux && PLATFORM=linux-`uname -m`
uname -a | grep -iq win && PLATFORM=windows-`uname -m`
[ -z "$PLATFORM" ] && { echo "Could not detect platform"; exit 1; }

usage() {
cat<<EOF
  Make this machines public addres available via dns
  Usage: seed.sh [coin] [ip]
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
if [ -z "$2" ]; then
  echo Specify an IP
  usage
fi

# Create "$1.crahen.net"
cat<<'EOF'|python - "$1" "$2"
import hashlib
import os
import sys
import time
import boto
from boto.route53.record import ResourceRecordSets

HOSTEDZONEID='Z2Z4WD6ZKJ4UL'
NAME=sys.argv[1] + '.crahen.net'
IP=sys.argv[2]

# Log the identity the upload is run as
conn = boto.connect_iam()
print 'Using Identity: %s' % conn.get_user().user.arn
print 'Using Path: %s' % os.getcwd()
#boto.set_stream_logger('pack')

conn = boto.connect_route53()
changes = ResourceRecordSets(conn, HOSTEDZONEID)

sets = conn.get_all_rrsets(HOSTEDZONEID, None)
for rset in sets:
  if rset.name == NAME + ".":
    previous_value = rset.resource_records[0]
    change = changes.add_change("DELETE", NAME + ".", "A", 60)
    change.add_value(previous_value)
change = changes.add_change("CREATE", NAME + ".", "A", 60)
change.add_value(IP)
result = changes.commit()
print result
EOF
