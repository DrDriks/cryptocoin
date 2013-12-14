#!/bin/bash -e
ROOT="$(cd `dirname $0`/..; pwd)"
# Get the placement from the instance metadata service
ZONE=$(wget -q -O - http://169.254.169.254/latest/meta-data/placement/availability-zone | sed -e 's,\r,,')
REGION=$(echo ZONE | sed -e 's,\r,,' -e 's,.$,,')
## Get the instance from the instance metadata service
INSTANCE=$(wget -q -O - http://169.254.169.254/latest/meta-data/instance-id | sed -e 's,\r,,')
# Get the tag for the instance from the ec2 API
TAG=$(ec2-describe-instances $INSTANCE --show-empty-fields --region $REGION | sed -e 's,\r,,' | grep TAG | grep URL)
# Get the pool URL from the tag.
echo $TAG | sed -e 's,.*URL[^h]*,,'
