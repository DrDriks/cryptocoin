#!/usr/bin/python
import json
import os
import time
import subprocess
import sys
from decimal import Decimal
from pprint import pprint

PERIOD=5*60

# Wallets can be slow an unresponsive while they process
# updates on a slow machine, this may need to be order minutes.
RETRIES=3
TIMEOUT=5

class Wallet:
  """Wrap a wallet and extract interesting information from it"""

  def __init__(self, symbol):
    self.symbol = symbol
    self.cmd=os.path.realpath(__file__).replace('wallet-scraper.py', symbol)
    self.var=os.path.realpath(__file__).replace('bin/wallet-scraper.py', 'var/run/hashcash/' + symbol)
    self.algo = 'unknown'
    with open(self.var + '/algorithm.properties', 'r') as f:
      self.algo = json.loads(''.join(f.readlines()))['algorithm']

  def GetNetworkAlgorithm(self):
    """Get the algorithm this wallet uses"""
    return self.algo

  def GetNetworkBlockCount(self):
    """Count total number of blocks in the blockchain."""
    return self.__fork__('getmininginfo')['blocks']

  def GetNetworkBlockTime(self, block=None):
    """Estimate time to next block"""
    return 1 / self.GetNetworkBlocksPerSecond(block)

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

  def GetYieldPerSecond(self):
    """Estimate of how many coins per second could be generated given a practical minimum hashrate of 1"""
    return self.GetNetworkCoinsPerSecond(hashrate=1)

  def GetStatistics(self):
    return dict({
     'network-symbol': self.symbol,
     'network-algorithm': self.GetNetworkAlgorithm(),
     'network-coin-count': self.GetNetworkCoinCount(),
     'network-coins-per-second': self.GetNetworkCoinsPerSecond(),
     'network-block-count': self.GetNetworkBlockCount(),
     'network-block-time': self.GetNetworkBlockTime(),
     'network-blocks-per-second':  self.GetNetworkBlocksPerSecond(),
     'network-block-difficulty': self.GetNetworkBlockDifficulty(),
     'network-hashes-per-second':  self.GetNetworkHashesPerSecond(),
     'network-timestamp': self.GetNetworkTimestamp(),
     'network-delay': time.time() - self.GetNetworkTimestamp(),
     'yield-per-second': self.GetYieldPerSecond()
    })

  def __fork__(self, *args):
    #
    def run(args):
      p = subprocess.Popen(' '.join(args), stdout=subprocess.PIPE, shell=True)
      output, errors = p.communicate()
      if errors:
        raise Exception(str(errors))
      output = output.strip()
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


def StoreWalletData(symbol, data):
  print json.dumps(data)


def DumpWalletData(symbol, data, period, window):
  True


if __name__ == "__main__":
  # Every PERIOD (5-min), measure the previous WINDOW
  # worth of data (30-min) and emit an aggregate dump
  symbol = sys.argv[1]
  wallet = Wallet(symbol)
  while True:
    now = time.time()
    data = wallet.GetStatistics()
    if data:
      StoreWalletData(symbol, data)
      DumpWalletData(symbol, data, PERIOD, 6*PERIOD)
    time.sleep(PERIOD-(time.time()-now))
