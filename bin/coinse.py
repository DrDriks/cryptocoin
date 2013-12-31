#!/usr/bin/python
import json
import os
import time
import urllib2
import subprocess
import sys
import sqlite3
from decimal import Decimal
from pprint import pprint

PERIOD=5*60
WINDOW=30*60

RETRIES=3
TIMEOUT=5

URL = 'https://www.coins-e.com/api/v2/markets/data/'

class Coinse:
  """Wrap coinse and extract exchange rates"""

  def __init__(self):
    self.cmd=os.path.dirname(os.path.realpath(__file__)) + '/coinbase.sh'
    self.var=os.path.dirname(os.path.dirname(os.path.realpath(__file__))) + 'var/run/hashcash/'
    self.db = '%s/coinse-%s.db' % (self.var, PERIOD)
    self.table = 'coinse'
    self.markets = dict({})

  def GetCoinbasePrices(self):
    """Get the effective bid and ask from coinbase"""
    ask = None
    bid = None
    p = subprocess.Popen([self.cmd], stdout=subprocess.PIPE, shell=True)
    for line in p.stdout:
      if not ask:
        ask = Decimal(line)
      else:
        bid = Decimal(line)
    p.wait()
    if p.returncode != 0:
      raise Exception("Failed to call " + self.cmd + "!")
    return (ask, bid)

  def GetCoinsePrices(self):
    """Get quotes for all of the interesting markets"""

    def GetMarkets():
       markets = None
       for retry in range(0, 3):
         try:
           response = urllib2.urlopen(URL)
           data = json.loads(response.read())
           return data['markets']
         except:
           time.sleep(TIMEOUT)
       raise Exception('Could not fetch %s' % URL)

    def GetMarketQuote(now, btcAskToUSD, btcBidToUSD, coin, market):
      ask = Decimal(market['marketstat']['ask'])
      bid = Decimal(market['marketstat']['bid'])
      vol = market['marketstat']['24h']['volume']
      return dict({'timestamp':now, 'coin':coin, 'ask':ask, 'bid':bid, 'volume':vol})

    now = time.time()
    now = now - (now%(5*60))
    data = []

    btcAskToUSD, btcBidToUSD = self.GetCoinbasePrices()
    data.append(dict({'timestamp':now, 'coin':'btc', 'ask':btcAskToUSD, 'bid':btcBidToUSD, 'volume':0}))

    markets = GetMarkets()
    for key in markets.keys():
      if key.endswith('_BTC'):
        coin = key.replace('_BTC', '')
        coin = coin.lower()
        p = GetMarketQuote(now, btcAskToUSD, btcBidToUSD, coin, markets[key])
        self.markets[coin] = p
        data.append(p)
    return data

  def GetBid(self, coin):
    coin = coin.lower()
    if not len(self.markets) > 0:
      self.GetCoinsePrices()
    print float(self.markets[coin]['bid'].to_eng_string())
    return float(self.markets[coin]['bid'].to_eng_string())

  def CacheSample(self):
    prices = self.GetCoinsePrices()
    if not prices:
      return
    conn = sqlite3.connect(self.db)
    conn.execute('create table if not exists %s (timestamp integer, coin varchar, ask decimal, bid decimal, volume integer, primary key (timestamp, coin));' % self.table)
    try:
      for data in prices:
         conn.execute('insert or replace into %s values (%s, \'%s\', %s, %s, %s);' % (self.table, data['timestamp'], data['coin'], data['ask'], data['bid'], data['volume']))
      conn.commit()
    finally:
      conn.close()

  def StoreSamples(self):
     True


if __name__ == "__main__":
  exchange = Coinse()
  last = -1
  while True:
    now = time.time()
    exchange.CacheSample()
    if now > last:
      exchange.StoreSamples()
      last = now + PERIOD
    time.sleep(PERIOD-(time.time()-now))
