package main

import (
	// "os"
	"context"
	"flag"
	"fmt"
	"log"
	"math/big"
	"math/rand"
	"strconv"
	"time"
	"zkevmchaintest/zkevml1bridge"

	"github.com/joho/godotenv"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/ethclient"
)

var TxHashes []common.Hash
var tnEnv map[string]string
var zeros []*big.Int

var miner string

var initL2Funds bool
var doDeposits bool
var doTxs bool
var showBal bool
var doWithDraws bool
var layer int
var testEnv string
var TxCount int
var TxSleep string

func init() {
	flag.BoolVar(&initL2Funds, "initL2Funds", false, "boolean, initialize L2 funds")
	flag.BoolVar(&doTxs, "doTxs", false, "boolean, if set, script will run simple Txs on selected layer, until exited")
	flag.BoolVar(&showBal, "showBal", false, "boolean, if set, script will calculate and display account balances in l1 and l2")
	flag.BoolVar(&doWithDraws, "doWithDraws", false, "boolean, if set, script will perform fund withdraws to l1, until exited")
	flag.BoolVar(&doDeposits, "doDeposits", false, "boolean, if set, script will perform fund deposits to l2, until exited, var layer defaults to 1")
	flag.IntVar(&layer, "layer", 1, "select layer, must be 1 or 2 - only relevant when doTxs is TRUE")
	flag.StringVar(&testEnv, "testEnv", "REPLICA", "select environment as test target")
	flag.IntVar(&TxCount, "TxCount", 1, "select number of Txs to execute")
	flag.StringVar(&TxSleep, "TxSleep", "1s", "select number of seconds to pause inbetween Txs || example: -TxSleep='3s'")
}

func main() {
	flag.Parse()
	// ADD A CONDITION TO FORCE THE PROGRAM TO EXIT IN CASE USER PROVIDES NON COMPATIBLE FLAGS
	TxSl, _ := time.ParseDuration(TxSleep)
	strlayer := strconv.Itoa(layer)
	tnEnv, err := godotenv.Read()
	if err != nil {
		fmt.Println(err)
		log.Fatal(err)
	}

	ksdir := tnEnv["KEYSTORE"]
	passw0rd := tnEnv["PASSWORD"]
	lOnebridge := tnEnv["L1BRIDGEADDR"]
	lTwobridge := tnEnv["L2BRIDGEADDR"]
	miner = tnEnv["MINERADDR"]

	// fmt.Printf("miner: %v\n", miner)

	//Random source to select account(s)
	source := rand.NewSource(time.Now().UnixNano())
	r := rand.New(source)

	_accounts, ks := LoadAccounts(ksdir)
	_ctx := context.Background()

	ethcl1, err := ethclient.Dial(tnEnv[testEnv+"_L1"])
	if err != nil {
		fmt.Println(err)
		log.Fatal(err)
	}
	ethcl2, err := ethclient.Dial(tnEnv[testEnv+"_L2"])
	if err != nil {
		fmt.Println(err)
		log.Fatal(err)
	}

	l1ChainId, err := ethcl1.NetworkID(_ctx)
	if err != nil {
		fmt.Println(err)
		log.Fatal(err)
	}

	// unlock keystore to enable Tx signing
	for _, account := range _accounts {
		ks.Unlock(account, passw0rd)
	}

	fmt.Printf("CLIENT SETUP:\n showBal: %v\ndoDeposits: %v\ndoTxs: %v\nlayer: %v\nenvironment: %v\nTxCount: %v\n", showBal, doDeposits, doTxs, layer, testEnv, TxCount)

	if showBal {

		bal := GetBalances(_accounts, *ethcl1, *ethcl2, _ctx)
		for _, b := range bal {
			fmt.Printf("account %x has %v funds in l2 and %v funds in l1\n", b.hexaddr, b.layer2Funds, b.layer1Funds)

		}
	}

	if doDeposits {
		strlayer = "1"
		ethcl, err := ethclient.Dial(tnEnv[testEnv+"_L"+strlayer])
		if err != nil {
			fmt.Println(err)
			log.Fatal(err)
		}
		chainId, err := ethcl.NetworkID(_ctx)
		if err != nil {
			fmt.Println(err)
			log.Fatal(err)
		}

		bridgeAddress := common.HexToAddress(lOnebridge)
		bridge, err := zkevml1bridge.NewZkevml1bridge(bridgeAddress, ethcl)
		if err != nil {
			fmt.Println(err)
			log.Fatal(err)
		}

		// ii := 0
		// TxHashes = nil
		for ii := 1; ii <= TxCount; ii++ {
			disMsgData, si, _ := NewDmsgData(&ks, miner, 1000000, _accounts, *ethcl, _ctx, r, chainId)
			fmt.Printf("account : %x || nonce: %v\ntokenNonce: %v\n", _accounts[si].Address, disMsgData._nonce, disMsgData._txOpts.Nonce)
			//Send transaction with generated bind.TransactOpts
			tx, err := bridge.DispatchMessage(disMsgData._txOpts, disMsgData._to, disMsgData._fee, disMsgData._deadline, disMsgData._nonce, disMsgData._data)
			if err != nil {
				fmt.Println(err)
				// log.Fatal(err)
			}

			// fmt.Printf("TxHash: %v\n %v", tx, ii)
			fmt.Printf("TxHash: %v\n %v\n", tx.Hash(), ii)
			TxHashes = append(TxHashes, tx.Hash())

			// fmt.Printf("TxCost: %v\n\n\n", tx.Cost())

			errr := ethcl.SendTransaction(_ctx, tx)
			if errr != nil {
				fmt.Println(errr)
				// log.Fatal(err)
			}

			// time.Sleep(2 * time.Second)
			time.Sleep(TxSl)
			fmt.Printf("Sent %v Txs so far\n", ii)
		}

	}

	//Set of dummy print statements to avoid unused variables error

	fmt.Println(lTwobridge)
	fmt.Println(ethcl2)
	fmt.Println(l1ChainId)
}
