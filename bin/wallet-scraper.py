#!/usr/bin/python
import json
import os
import time
import subprocess
import sys
import sqlite3
from decimal import Decimal
from pprint import pprint
from cryptsy import Cryptsy
from coinse import Coinse

PERIOD=5*60
WINDOW=30*60

# Wallets can be slow an unresponsive while they process
# updates on a slow machine, this may need to be order minutes.
RETRIES=3
TIMEOUT=5

class Wallet:
  """Wrap a wallet and extract interesting information from it"""

  def __init__(self, symbol):
    self.symbol = symbol
    self.cmd=os.path.dirname(os.path.realpath(__file__)) + '/' + symbol
    self.var=os.path.dirname(os.path.dirname(os.path.realpath(__file__))) + '/var/run/hashcash/' + symbol
    self.algo = 'unknown'
    with open(self.var + '/algorithm.properties', 'r') as f:
      self.algo = json.loads(''.join(f.readlines()))['algorithm']
    self.db = '%s/currency-statistics-%s.db' % (self.var, PERIOD)
    self.table = 'currency_statistics'

  def GetAlgorithm(self):
    """Get the algorithm this wallet uses"""
    return self.algo

  def GetSymbol(self):
    """Get the symbl this wallet uses"""
    return self.symbol

  def GetNetworkBlockCount(self):
    """Count total number of blocks in the blockchain."""
    return self.__fork__('getmininginfo')['blocks']

  def GetNetworkBlocksPerSecond(self, block=None, hashrate=None):
    """Estimate of how many blocks per second the network is generating"""
    if not hashrate:
      hashrate = self.GetNetworkHashesPerSecond()
    return 1 / ((self.GetNetworkBlockDifficulty(block) * (2**32)) / hashrate)

  def GetNetworkBlockDifficulty(self, block=None):
    """Get difficulty for a block"""
    # Current difficulty
    if not block:
      return self.__fork__('getmininginfo')['difficulty']
    # Specific historical difficulty
    blockhash = self.__fork__('getblockhash', str(block))
    return self.__fork__('getblock', blockhash)['difficulty']

  def GetNetworkBlockReward(self, block=None):
    if not block:
      block = self.__fork__('getmininginfo')['blocks']
    blockhash = self.__fork__('getblockhash', str(block))
    block = self.__fork__('getblock', blockhash)
    if block.get('mint'):
      return block['mint']
    # If there's no mint, count coinbase values
    reward = 0
    for tx in block['tx']:
      raw = self.__fork__('getrawtransaction', tx)
      tx = self.__fork__('decoderawtransaction', raw)
      for vin in tx['vin']:
        if vin.get('coinbase'):
          for vout in tx['vout']:
            if vout.get('value'):
              reward += vout['value']
    return reward

  def GetNetworkHashesPerSecond(self):
    """Get the hash power of the network"""
    return self.__fork__('getmininginfo')['networkhashps']

  def GetNetworkCoinCount(self):
    """Get total number of coins"""
    return self.__fork__('getinfo')['moneysupply']

  def GetNetworkCoinsPerSecond(self, hashrate=None):
    """Estimate of how many blocks per second the network is generating"""
    return self.GetNetworkBlocksPerSecond(hashrate=hashrate) * self.GetNetworkBlockReward()

  def GetNetworkTimestamp(self, block=None):
    if not block:
      block = self.__fork__('getmininginfo')['blocks']
    blockhash = self.__fork__('getblockhash', str(block))
    block = self.__fork__('getblock', blockhash)
    timestamp = block['time']
    return timestamp - (timestamp%PERIOD)

  def GetCommonHashRate(self):
    """Get a commonly base hashrate to make comparison simpler"""
    if self.algo == 'scrypt':
      return 1000
    if self.algo == 'sha256':
      return 1000000
    raise Exception(self.algo + ' not supported')

  def GetYieldPerSecond(self, hashrate=1):
    """Estimate of how many coins per second could be generated given a practical minimum hashrate of 1"""
    return 1/((2.5*(2**32))/(hashrate))*self.GetNetworkBlockReward()

  def GetYieldPerSecondBTC(self, hashrate=1):
    """Estimate of how many BTC per second could be generated given a practical minimum hashrate of 1"""
    return Coinse().GetBid(self.symbol) * self.GetYieldPerSecond(hashrate)

  def GetYieldPerSecondUSD(self, hashrate=1):
    """Estimate of how many USD per second could be generated given a practical minimum hashrate of 1"""
    return Coinse().GetBid('btc') * self.GetYieldPerSecondBTC(hashrate)

  def GetCurrencyStatistics(self):
    exchange = Coinse()
    symbol = self.GetSymbol()
    btcRate = exchange.GetBid(symbol)
    usdRate = btcRate * exchange.GetBid('btc')
    return dict({
     'symbol': symbol,
     'algorithm': self.GetAlgorithm(),
     'network-coin-count': self.GetNetworkCoinCount(),
     'network-coins-per-second': self.GetNetworkCoinsPerSecond(),
     'network-block-count': self.GetNetworkBlockCount(),
     'network-blocks-per-second':  self.GetNetworkBlocksPerSecond(),
     'network-block-difficulty': self.GetNetworkBlockDifficulty(),
     'network-hashes-per-second':  self.GetNetworkHashesPerSecond(),
     'network-timestamp': self.GetNetworkTimestamp(),
     'network-delay': time.time() - self.GetNetworkTimestamp(),
     'exchange-name': exchange.GetName(),
     'exchange-price-btc': btcRate,
     'exchange-price-usd': usdRate,
     'yield-per-hour': self.GetYieldPerSecond()*60*60,
     'yield-per-hour-btc': self.GetYieldPerSecondBTC()*60*60,
     'yield-per-hour-usd': self.GetYieldPerSecondUSD()*60*60
    })

  def __fork__(self, *args):
    #
    def run(args):
      p = subprocess.Popen(' '.join(args), stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True)
      output, errors = p.communicate()
      output = output.strip()
      if errors:
        raise Exception(str(errors))
      if output.startswith('error:'):
        raise Exception(output.replace('error:',''))
      if output.startswith('{') or output.startswith('['):
        output = json.loads(output)
      return output
    #
    v = [self.cmd]
    for arg in args:
      v.append(arg)
    args = v
    #
    for attempt in range(0,RETRIES):
      try:
        return run(args)
      except Exception, e:
        if attempt == RETRIES-1:
          raise e
        time.sleep(TIMEOUT)

  def GetInterval(self):
    """Estimate an update interval"""
    return max((1 / self.GetNetworkBlocksPerSecond()) / 3, 120)

  def CacheSample(self):
    conn = sqlite3.connect(self.db)
    conn.execute('create table if not exists %s ('
                 'symbol varchar,'
                 'network_timestamp integer,'
                 'network_coin_count decimal,'
                 'network_coins_per_second decimal,'
                 'network_block_count decimal,'
                 'network_blocks_per_second decimal,'
                 'network_block_difficulty decimal,'
                 'network_hashes_per_second decimal,'
                 'network_delay integer,'
                 'exchange_name string,'
                 'exchange_price_btc decimal,'
                 'exchange_price_usd decimal,'
                 'yield_per_hour decimal,'
                 'yield_per_hour_btc decimal,'
                 'yield_per_hour_usd decimal,'
                 'primary key(symbol, network_timestamp));' % self.table)
    try:
      data = self.GetCurrencyStatistics()
      pprint(data)
      conn.execute('insert or replace into %s values (\'%s\', %s, %s, %s, %s, %s, %s, %s, %s, \'%s\', %s, %s, %s, %s, %s);' % (self.table,
        data['symbol'],
        data['network-timestamp'],
        data['network-coin-count'],
        data['network-coins-per-second'],
        data['network-block-count'],
        data['network-blocks-per-second'],
        data['network-block-difficulty'],
        data['network-hashes-per-second'],
        data['network-delay'],
        data['exchange-name'],
        data['exchange-price-btc'],
        data['exchange-price-usd'],
        data['yield-per-hour'],
        data['yield-per-hour-btc'],
        data['yield-per-hour-usd']))
      conn.commit()
    finally:
      conn.close()

  def StoreSamples(self):
    True


if __name__ == "__main__":
  symbol = sys.argv[1]
  wallet = Wallet(symbol)
  last = -1
  while True:
    now = time.time()
    INTERVAL = wallet.GetInterval()
    wallet.CacheSample()
    if now > last:
      wallet.StoreSamples()
      last = now + PERIOD
    time.sleep(INTERVAL-(time.time()-now))
