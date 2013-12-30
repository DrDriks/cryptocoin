#!/bin/bash
# Print the ask and the bid on coinbase
TMP=`mktemp`
curl https://coinbase.com/charts -o "$TMP" 2> /dev/null
grep 'Sell Price' "$TMP" | sed -ne 's,.*Sell Price <strong>\$\([0-9]*\).*,\1,p'
grep 'Buy Price' "$TMP" | sed -ne 's,.*Buy Price <strong>\$\([0-9]*\).*,\1,p'
rm -f "$TMP"
