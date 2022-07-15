from brownie import Check, Check2, Check3, Check4, Check5
from brownie.network import accounts
from web3 import Web3
from pathlib import Path
from scripts import utils as ut
import time
import os
import json
import sys

envfile = "environment.json"
env = ut.getEnv(envfile)
projectDir = ut.getProjectDir(env)
keyfilesDir = projectDir.joinpath(env["keystoredir"])
deploymentsDir = projectDir.joinpath(f'brownie/{env["deployments"]}')

def main():
    keyfiles = [i for i in os.listdir(keyfilesDir) if "UTC" in i]
    print(keyfiles)
    print(f"{keyfilesDir}{keyfiles[0]}")
    accounts.load(f"{keyfilesDir}/{keyfiles[0]}", "password")
    owner = accounts[0]

    # check = Check.deploy({"from": owner})
    # check2 = Check2.deploy({"from": owner})
    # check3 = Check3.deploy({"from": owner})
    # check4 = Check4.deploy({"from": owner})
    check5 = Check5.deploy({"from": owner})    
