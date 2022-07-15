from brownie import Check, Check2, Check3, Check4, Check5
from brownie.network import accounts
from scripts import utils as ut
from pprint import pprint
import os, json
from pathlib import Path
from web3 import Web3
from web3.middleware import geth_poa_middleware
import requests
import time
import logging
import json
import pandas as pd


envfile = "environment.json"
env = ut.getEnv(envfile)
projectDir = ut.getProjectDir(env)
keyfilesDir = projectDir.joinpath(env["keystoredir"])
deploymentsDir = projectDir.joinpath(f'brownie/{env["deployments"]}')
testEnvs = env["testEnvironments"].split()

def main():

    print("Select test environment:\n")
    for i in range(len(testEnvs)):
        print(f"{i} : {testEnvs[i]}")
    testenv = testEnvs[int(input("insert environment index:"))]
    circuit_degree = str(input('degree: '))
    opcodes = pd.read_csv(f'{projectDir}/brownie/opcodes',sep='|')
    opcodes=opcodes.set_index('opcode')
    proof = bool(input("query proofs? (True/False) :")) 
    numOfiterations = int(input("start number of opcode iterations: "))
    step = int(input("step: "))
    try:
        stop = int(input("stop at: "))
    except:
        stop = 10000000
        print("No hard stop was provided. Will run until interrupted with CTRL-C or a proof failure occurs")

    keyfiles = [i for i in os.listdir(keyfilesDir) if "UTC" in i]
    accounts.load(f"{keyfilesDir}/{keyfiles[0]}", "password")
    owner = accounts[0]

    l2_w3 = Web3(Web3.HTTPProvider(env["rpcUrls"][f'{testenv}'"_BASE"]+"l2"))
    # l2_w3 = Web3(Web3.HTTPProvider(f'{env["rpcUrls"][{testenv}"_BASE"]}l2'))
    # l2_w3 = Web3(Web3.HTTPProvider(f'{env["rpcUrls"]["REPLICA_BASE"]}l2'))
    l2_w3.middleware_onion.inject(geth_poa_middleware, layer=0)
    cid = str(l2_w3.eth.chainId)

    jsonmap = json.load(open(f"{projectDir}/brownie/{env['deployments']}/map.json"))

    # checkaddr2 = jsonmap[cid]["Check2"][0]
    # check2 = Check2.at(checkaddr2)

    # checkaddr3 = jsonmap[cid]["Check3"][0]
    # check3 = Check3.at(checkaddr3)

    # checkaddr4 = jsonmap[cid]["Check4"][0]
    # check4 = Check4.at(checkaddr4)

    checkaddr5 = jsonmap[cid]["Check5"][0]
    check5 = Check5.at(checkaddr5)

    # proverUrl = f'{env["rpcUrls"]["REPLICA_BASE"]}prover'
    proverUrl = env["rpcUrls"][f'{testenv}'"_BASE"]+"prover"

    proofFailed = False

    # numOfiterations = 2000

    benchResult = []
    while not proofFailed and numOfiterations <= stop:
        
        stepResult = {}
        print(f'Submitting Tx with {numOfiterations} iterations of MULMOD')
        # tx = check2.checkBatch((50,60,2823,numOfiterations), {"from": owner})
        tx = check5.checkBatchYul(((numOfiterations),),{"from": owner})
        traceDone = False
        while not traceDone:
            try:
                tr = tx.trace
                traceDone = True
                print('Tx trace done')
            except:
                print("failed to get tx trace")
        stepResult["OpCodes"] = numOfiterations
        stepResult["Block"] = tx.block_number
        stepResult["GasUsed"] = tx.gas_used
        sourceURL = "http://leader-testnet-geth:8545/"
        start = int(time.time())
        # data=f'{{"jsonrpc":"2.0", "method":"proof", "params":[{tx.block_number},"{sourceURL}", false], "id":{tx.block_number}}}'
        data=f'{{"jsonrpc":"2.0", "method":"proof", "params":[{{"block":{tx.block_number},"rpc":"{sourceURL}", "retry":false, "param": "/testnet/{circuit_degree}.bin"}}], "id":{tx.block_number}}}'
        proofCompleted = False
        while not proofCompleted:
            # print(f"Waiting for block {tx.block_number} proof")
            r = requests.post(proverUrl,data)
            error = 'error' in r.json().keys()
            # pprint(r.json())
            if error:
                print(f'ERROR: Block: {tx.block_number} -- {r.json()["error"]}')
                proofCompleted = True
                proofFailed = error
                stepResult["Error"] = r.json()["error"]
            elif 'result' in r.json().keys():
                result = r.json()['result']
                proofCompleted = result != None
                if proofCompleted:
                    # stop = int(time.time())
                    with open('/home/marios/TxTraceCheck5.json', 'w') as writeme:
                        json.dump(tr, writeme)
                    duration = r.json()["result"]["duration"]/1000
                    stepResult["ProofDuration"] = duration
                    mins = (duration - duration%60)/60
                    pprint(r.json()['result'])
                    # print(f'Proof for block {tx.block_number} generated in {mins} minutes and {duration - 60*mins} seconds\n{r.json()["result"]}')
                    print(f'Proof for block {tx.block_number} with {numOfiterations} MULMODs : generated in {mins} minutes and {duration - 60*mins} seconds\nOr {duration} seconds')

            
        numOfiterations+=step

        benchResult.append(stepResult)

        # with open('/home/marios/TxTraceCheck5.json', 'w') as writeme:
        #     json.dump(tr, writeme)
    # with open('/home/marios/TxTraceCheck5.json', 'w') as writeme:
    #     json.dump(tr, writeme)
    with open('/home/marios/resultMULMOD5.json', 'w') as writeme:
        json.dump(benchResult, writeme)