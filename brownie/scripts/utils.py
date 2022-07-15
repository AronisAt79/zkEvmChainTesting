from brownie.network import accounts
from web3 import Web3
from pathlib import Path
import time
import os
import json
import sys


def getEnv(filename):
    env = json.load(open(filename))

    return env

def getBrownieCwd():
    user = os.getlogin()
    
def loadMap(filename):
    map =  json.load(open())
    return map

def Contracts(map):
    contracts = {}
    networks = map.keys()
    for net in networks:
        contracts[net] = []
    for net in contracts.keys():
        for ctr in map[net].keys():
            contracts[net].append(ctr)
    return contracts


def getProjectDir(env):
    current=Path(os.getcwd())
    pdir = [i for i in current.parents if str(i).endswith(env['parentDir'])]
    if len(pdir) == 1:
        return pdir[0]
    else: 
        print("Error: could not determine brownie project location")
        sys.exit(1)


def getBlockGasCostFromTrace(tx,txtrace):
    pass


def getOCsGasCost(oc, txtrace):
    numberOfOCsInBlock = 0
    TotalGasOfOCs = 0

def getBlockCircuitCostFromOCs(txtrace, oc=''):
    '''Calculates the total block circuit cost. If opcode (op) is defined,
       function returns the circuit cost contribution of the given opcode 
    '''
    pass