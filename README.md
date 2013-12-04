Overview:

This provides simple workspace for managing a few different types of wallets.


Commands:

 pack.sh - walks through wallet/ and packs the wallet software and configuration for each currency into release/.
 unpack.sh - walks through release/ and unpacks the wallet software and configuration for each currency into wallet/.
 snapshot.sh - take a snapshot of the blockchain into snapshot/.
 restore.sh - restore a snapshot of the blockchain into wallet/.


Bootstrap:
 
 Cut and paste into a cygwin terminal, where COIN is FeatherCoin, BitCoin, etc. -

  mkdir cryptocoin && cd cryptocoin
  wget https://s3-us-west-2.amazonaws.com/storage.crahen.net/cryptocoin/bootstrap.sh
  chmod a+x bootstrap.sh
  ./bootstrap.sh $COIN

 To launch that wallet -

  ./wallet/$COIN/wallet.sh

 To get the balance of that wallet -

  ./wallet/$COIN/client.sh getaccountbalance ''

Getting Started:

  # Get Started
  cd cryptocoin

  # Install a Wallet
  ./unpack.sh

  # Restore Blockchain
  ./restore.sh AnonCoin

  # Save Blockchain
  ./snapshot.sh LiteCoin

