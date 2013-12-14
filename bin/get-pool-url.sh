#!/bin/bash -e
ROOT="$(cd `dirname $0`/..; pwd)"
# Get the instance id from the instance metadata service
INSTANCE=$(wget -q -O - http://169.254.169.254/latest/meta-data/instance-id | sed -e 's,\r,,')
# Get the tag for the instance from the ec2 API
TAG=$(ec2-describe-instances $INSTANCE --show-empty-fields  | sed -e 's,\r,,' | grep TAG | grep URL)
# Get the pool URL from the tag.
echo $TAG | sed -e 's,.*URL[^h]*,,'
