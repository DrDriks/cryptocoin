#!/usr/bin/python
import os
from os import listdir
from os.path import isfile

def GetCoins():
  """Get a list of coins there is automation for"""
  coins = []
  for f in listdir(os.path.dirname(os.path.realpath(__file__))):
    if not f.endswith('.py') and not f.endswith('.sh'):
      coins.append(os.path.basename(f))
  return coins

if __name__ == "__main__":
  for coin in GetCoins():
    print coin
