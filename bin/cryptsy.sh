#!/bin/sh -ex
ROOT="$(cd `dirname $0`/..; pwd)"
cd "$ROOT"
cat<<'EOF'|python - "$1"
import json
import sys
import time
import urllib2

def format_cryptsy_market_data(market, buyorders, sellorders, recenttrades):
  """Called for each conversion we're interested in"""
  print buyorders
  # .2% fee on buy
  # .3% fee on buy

def parse_cryptsy_market_data(market, coin, alt):
  k = '%s/%s' % (coin, alt,)
  data = market.get(k)
  if not data:
    k = '%s/%s' % (alt, coin,)
    data = market.get(k)
    if not data:
      return None
  if not data['label']:
    return None
  sellorders = []
  if data.has_key('sellorders'):
    sellorders = data['sellorders']
    del data['sellorders']
  buyorders = []
  if data.has_key('buyorders'):
    buyorders = data['buyorders']
    del data['buyorders']
  recenttrades = []
  if data.has_key('recenttrades'):
    recenttrades = data['recenttrades']
    del data['recenttrades']
  format_cryptsy_market_data(data, buyorders, sellorders, recenttrades)

def get_cryptsy_market_data():
  """Get the market data"""
  req = urllib2.Request('http://pubapi.cryptsy.com/api.php?method=marketdatav2')
  response = urllib2.urlopen(req).read()
  data = json.JSONDecoder().decode(response)
  if not data or not data.has_key('success') or data.get('success') != 1:
    raise Exception('Failed to get status')
  if not data or not data.has_key('return'):
    raise Exception('Failed to get result')
  data = data.get('return')
  if not data or not data.has_key('markets'):
    raise Exception('Failed to get markets')
  return data.get('markets')

def get_market_data():
  """Convert the cryptsy market data into a normalized form"""
  market = get_cryptsy_market_data()
  parse_cryptsy_market_data(market, "BTC", "LTC")
  parse_cryptsy_market_data(market, "BTC", "FTC")
  parse_cryptsy_market_data(market, "BTC", "TAG")
  parse_cryptsy_market_data(market, "BTC", "PPC")
  parse_cryptsy_market_data(market, "BTC", "PXC")
  parse_cryptsy_market_data(market, "BTC", "MEG")
  parse_cryptsy_market_data(market, "BTC", "WDC")
  parse_cryptsy_market_data(market, "BTC", "DGC")
  parse_cryptsy_market_data(market, "BTC", "TAG")
  parse_cryptsy_market_data(market, "BTC", "NVC")
  parse_cryptsy_market_data(market, "BTC", "SBC")
  parse_cryptsy_market_data(market, "BTC", "FRC")
  parse_cryptsy_market_data(market, "BTC", "FRK")
  parse_cryptsy_market_data(market, "BTC", "GLD")
  parse_cryptsy_market_data(market, "BTC", "ORB")
  parse_cryptsy_market_data(market, "BTC", "TRC")

#while True:
get_market_data()
#time.sleep(60*5)
EOF
