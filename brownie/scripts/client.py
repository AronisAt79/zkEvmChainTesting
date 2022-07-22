from brownie import Check5, CheckSdiv
from brownie.network import accounts
from scripts import utils as ut
from pprint import pprint
from pathlib import Path
from web3 import Web3
from web3.middleware import geth_poa_middleware
import os, requests, time, logging, json, sys, time
import pandas as pd
import pdb

global numOfiterations
# INSTANTIATE MAIN OBJECTS AND BASIC ENVIRONMENT PARAMETERS
envfile = "environment.json"
env = ut.getEnv(envfile)
projectDir = ut.getProjectDir(env)
keyfilesDir = projectDir.joinpath(env["keystoredir"])
deploymentsDir = projectDir.joinpath(f'brownie/{env["deployments"]}')
resultsDir = projectDir.joinpath(f'brownie/{env["resultsdir"]}')
# calibrate, op, d, testenv, degree, proof, numOfiterations, step, stop = ut.getUserInputs(env)
keyfiles = [i for i in os.listdir(keyfilesDir) if "UTC" in i]
accounts.load(f"{keyfilesDir}/{keyfiles[0]}", "password")
owner = accounts[0]
jsonmap = json.load(open(f"{projectDir}/brownie/{env['deployments']}/map.json"))
opcodeDF = ut.opCodes()
user = os.getlogin()

def main():
    calibrate, op, d, testenv, degree, proof, numOfiterations, step, stop = ut.getUserInputs(env)
    l2_w3 = Web3(Web3.HTTPProvider(env["rpcUrls"][f'{testenv}'"_BASE"]+"l2"))
    l2_w3.middleware_onion.inject(geth_poa_middleware, layer=0)
    cid = str(l2_w3.eth.chainId)
    proverUrl = env["rpcUrls"][f'{testenv}'"_BASE"]+"prover"

    # INSTANTIATE CONTRACT OBJECTS
    checkaddr5 = jsonmap[cid]["Check5"][0]
    check5 = Check5.at(checkaddr5)

    checksdivaddr5 = jsonmap[cid]["CheckSdiv"][0]
    checksdiv = CheckSdiv.at(checksdivaddr5)

    if calibrate:
        print('CALIBRATING')
        # SEND A TX WITH A LARGE NUMBER OF OPCODE EXECUTIONS TO EVALUATE TOTAL and OPCODE CIRCUIT COST
        tx = ut.sendTx(50000,checksdiv,owner)
        tr = ut.getTxTrace(tx)
        gasUsed = tx.gas_used
        gasFromOC = ut.getOCsGasCost(op,tr)
        # PERCENTAGE OF GAS SPENT FOR SPECIFIC OPCODE EXECUTION AGAINST Tx GAS_USED
        gasRatio = gasFromOC/gasUsed 
        totalCircuitCost, OpCodeCircuitCost = ut.getBlockCircuitCostFromOCs(opcodeDF,tr,op)
        OcContrib = OpCodeCircuitCost/totalCircuitCost
        MaxCircuitCostsPerDegree = {i:2**i for i in d}

        # DETERMINE THE THEORETICAL MAX MUMBER OF OPCODEs WE CAN EXECUTE WITH GIVEN CIRCUIT
        circuitCostOPs = MaxCircuitCostsPerDegree[degree]*OcContrib
        opcodesInGivenK = int(circuitCostOPs/opcodeDF.loc[op]["h"])
        theoreticalGas = int(gasUsed*(opcodesInGivenK/50000))

        # ROUND DOWN TO PREVIOUS THOUSAND
        numOfiterations = opcodesInGivenK - opcodesInGivenK%1000

        print(f'Degree is {degree}. Maximum theoretical value of h per block that we can generate proof')
        print(f'is {MaxCircuitCostsPerDegree[degree]}. With existing smart contract, this corresponds to execution')
        print(f'of {opcodesInGivenK} {op}s with a total block gas of {theoreticalGas}')

        if theoreticalGas > 1000000:
            opcodesInGivenK = (gasRatio*1000000)/opcodeDF.loc[op]["g"]
            numOfiterations = opcodesInGivenK - opcodesInGivenK%1000

            print(f'We dont want to exceed 1M gas, so adjusting number of {op} executions. Will do {numOfiterations} for ~ 1M gas')            

    proofFailed = False

    benchResult = []
    while not proofFailed and numOfiterations <= stop:
        
        print(f'Submitting Tx with {numOfiterations} iterations of {op}')
        tx = ut.sendTx(numOfiterations,checksdiv,owner)
        tr = ut.getTxTrace(tx)

        sourceURL = "http://leader-testnet-geth:8545/"
        # start = int(time.time())
        # data=f'{{"jsonrpc":"2.0", "method":"proof", "params":[{tx.block_number},"{sourceURL}", false], "id":{tx.block_number}}}'
        if proof:
            stepResult,proofCompleted,proofFailed=ut.getProofState(proverUrl,sourceURL,tx,degree,numOfiterations,resultsDir,tr, op, step,opcodeDF)
        else:
             stepResult = {}
            
        numOfiterations+=step

        benchResult.append(stepResult)

        # with open('/home/marios/TxTraceCheck5.json', 'w') as writeme:
        #     json.dump(tr, writeme)

    # with open(f'/home/{}/TxTraceCheck5.json', 'w') as writeme:
    #     json.dump(tr, writeme)
    with open(f'{resultsDir}/TxTrace-Degree-{degree}-{op}_{numOfiterations-step}.json', 'w') as writeme:
                    json.dump(tr, writeme)
    with open(f'{resultsDir}/Result-Degree-{degree}-{op}_{numOfiterations-step}.json', 'w') as writeme:
        json.dump(benchResult, writeme)
