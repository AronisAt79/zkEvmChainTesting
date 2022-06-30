from brownie import Check
from brownie.network import accounts
from web3 import Web3
import os
# from decimal import Decimal

keyfilesdir = "../keystore/"

# l1_w3 = Web3(Web3.HTTPProvider('https://zkevmchaingeth1.efprivacyscaling.org/rpc/l1'))
l2_w3 = Web3(Web3.HTTPProvider('https://zkevmchaingeth1.efprivacyscaling.org/rpc/l2'))

def main():
    keyfiles = [i for i in os.listdir(keyfilesdir) if "UTC" in i]

    accounts.load(f"{keyfilesdir}{keyfiles[0]}")
    owner = accounts[0]

    b = l2_w3.eth.blockNumber
    print(b)
    # print(l2_w3.isConnected())
    # admin = accounts[3]
    # user1 = accounts[0]
    # user2 = accounts[1]

    mulmod = Check.deploy({"from": owner})
    # print(mulmod)

    # name = token.name()
    # symbol = token.symbol()
    # decimals = token.decimals()
    # balanceOfAdmin = token.balanceOf(admin)
    # domainSep = token.DOMAIN_SEPARATOR()

    # print(domainSep)
    # print(name, symbol, decimals)
    # print(f"Balance of {admin} is {balanceOfAdmin*1e-18}")

    # tx1 = token.transfer(user1, w3.toWei(1, 'ether'))
    # tx1.wait(1)

    # newBalanceOfAdmin = token.balanceOf(admin)
    # newBalanceOfUser1 = token.balanceOf(user1)

    # print(f"User {admin}: {newBalanceOfAdmin}")
    # print(f"User {user1}: {newBalanceOfUser1}")

    # print(w3.eth.get_balance(admin.address)*1e-18)
    # print(w3.eth.get_balance('0x8D5004fc1531945146Fb2b87231C9FE0e82624a9')*1e-18)
    # print(user1.balance()*1e-18)
    # print(user2.balance()*1e-18)
