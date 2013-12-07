Overview:


Bootstrap Workspace:

 curl https://.../release/bin/bootstrap.sh | sh [workspace]
 cd [workspace]


Create Keyrings:

 Generate a new keyring to be used with your collection of wallets. This will generate a new set of addresses and private keys for each currency:

 ./bin/create-keyring.sh [keyring-name]


 e.g.
 ./bin/create-keyring.sh master


Install Addresses:

 Install the addresses from your keyring into the wallets. This will allow you to create transactions to and from the addresses you control.

 ./bin/install-keyring-public.sh [keyring-name]


 e.g.
 ./bin/install-keyring-public.sh master

