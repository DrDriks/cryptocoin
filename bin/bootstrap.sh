#!/bin/sh -ex
shopt -s extglob

ROOT=$(cd `dirname $0`/..; pwd; cd - 2>&1 > /dev/null)

function usage {
  echo "Error: $1"
  echo "Usage: `basename $0` <installation-directory> <configuration>"
  exit 1
}


LOG=/tmp/bootstrap.log
if [ x"$1" == x ]; then
  usage "No target directory specified"
else
  TARGET="$1"
fi
BINLIB="$TARGET/lib/hashcash"
mkdir -p "$BINLIB"
if [ x"$2" == x ]; then
  usage "No configuration specified"
else
  if [ ! -e "$2" ]; then
    usage "Configuration doesn't exist"
  fi
  URL="file://$2"
fi


# Configure workspace to run wallet.
configure() {
  SYM="$1"
  COIN="$2"
  PORT="$3"
  [ -z "$1" -o -z "$2" -o -z "$3" ] && exit 1
  BIN="$TARGET"/bin/$SYM
  RUN="$TARGET/var/run/hashcash/$SYM"
  mkdir -p "$TARGET"/bin
  mkdir -p "$RUN"
cat>"$BIN"<<EOF
#!/bin/sh
function ping {
  while : ; do
    netstat -ltn | grep -q :$PORT && break
    echo Waiting for wallet
    sleep 30
  done
}
ping &
exec "$BINLIB"/${COIN}d -conf="$BINLIB"/$COIN.conf -datadir="$RUN" "\$@"
EOF
  chmod a+rx "$BIN"
  CONF="$BINLIB"/${COIN}.conf
cat>"$CONF"<<EOF
rpcallowip=127.0.0.1
rpcconnect=127.0.0.1
rpcuser=user
rpcpassword=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)
rpcport=$PORT
txindex=1
EOF
  chmod a+r "$CONF"
}


# Setup a workspace to build and install a wallet.
build() {
  COIN="$1"
  REPO="$2"
  # Pull
  [ -z "$1" -o -z "$2" ] && exit 1
  if [ ! -d "$COIN" ]; then
    git clone "$REPO" "$COIN"
    cd "$COIN"
  else
    cd "$COIN"
    git pull
  fi
  # Build
  if [ -e ./autogen.sh ]; then
    ./autogen.sh
    ./configure --without-miniupnpc --without-qt --disable-silent-rules --with-incompatible-bdb --prefix="$TARGET"
    cd src
    make -j4
  else
    cd src
    mkdir -p obj
    make -j4 -f makefile.unix USE_UPNP=-
  fi
  # Install
  BIN=$(ls -1 | grep -i ${COIN}d | sort -n | head -n 1)
  cp -fp "$BIN" "$BINLIB"/${COIN}d
}


# Setup a workspace to build, configure and install a wallet.
function bootstrap {
  SYM="$1"
  COIN="$2"
  ALGO="$3"
  PORT="$4"
  REPO="$5"
  DIR="`pwd`"
  [ -z "$1" -o -z "$2" -o -z "$3" -o -z "$4" -o -z "$5" ] && exit 1
  OLDDIR="`pwd`"
  DIR="$TARGET/var/tmp/hashcash"
  mkdir -p "$DIR"/$SYM
  cd "$DIR"
  echo '{"algorithm":"'$ALGO'"}' > "$TARGET"/var/run/hashcash/$SYM/algorithm.properties
  build "$COIN" "$REPO"
  configure "$SYM" "$COIN" "$PORT"
  cd "$OLDDIR"
}


# Use the configuration file to decide what to bootstrap for each type of coin.
declare -A CONFIG
curl "$URL" 2> "$LOG"| while read line; do
  [ x == x"$line" ] && continue
  [ "${line/\#/}" != "$line" ] && continue
  SYM=${line/.*/}
  KEY=${line//=*/}
  KEY=$SYM-${KEY/*./}
  VAL=${line/*=/}
  [ -z "$SYM" -o -z "$KEY" -o -z "$VAL" ] && continue
  CONFIG["$KEY"]="$VAL"
  [ -z "${CONFIG[$SYM-name]}" ] && continue
  [ -z "${CONFIG[$SYM-algo]}" ] && continue
  [ -z "${CONFIG[$SYM-port]}" ] && continue
  [ -z "${CONFIG[$SYM-repo]}" ] && continue
  bootstrap $SYM "${CONFIG[$SYM-name]}" "${CONFIG[$SYM-algo]}" "${CONFIG[$SYM-port]}" "${CONFIG[$SYM-repo]}"
done
cp -fp "$ROOT"/bin/*.sh "$TARGET"/bin
cp -fp "$ROOT"/bin/*.py "$TARGET"/bin
