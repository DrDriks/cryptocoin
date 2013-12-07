#!/bin/sh -e
if [ ! -e "$1" ]; then
  echo Specify a workspace directory
  exit 1
fi

mkdir -p "$1"/bin
cd "$1"

list() {
cat<<EOF
client.sh
coins.sh
create-keyring.sh
install-keyring-private.sh
install-keyring-public.sh
pack.sh
pack-all.sh
restore.sh
snapshot.sh
snapshot-all.sh
unpack.sh
unpack-all.sh
wallet.sh
EOF
}

list | while read FILE; do
  curl https://cryptocoin.crahen.net/bin/$FILE -O bin/$FILE
  chmod a+x bin/$FILE
done
