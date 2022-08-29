from brownie import CheckSdiv
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

    checksdiv = CheckSdiv.deploy({"from": owner})
