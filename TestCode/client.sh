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
	"zkevmchaintest/zkevmmessagedispatcher"

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

var oneDepositNoLoop bool
var oneWithDrawNoLoop bool
var balanceDivisor int64

var testFuzz bool

var crosschaintxDeposit bool

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

	flag.BoolVar(&oneDepositNoLoop, "oneDepositNoLoop", false, "boolean, send one deposit outside of loop")
	flag.BoolVar(&oneWithDrawNoLoop, "oneWithDrawNoLoop", false, "boolean, send one oneWithDrawNoLoop outside of loop")
	flag.Int64Var(&balanceDivisor, "balanceDivisor", 1000000, "int64, amount to transfer equals balance/balanceDivisor")

	flag.BoolVar(&testFuzz, "testFuzz", false, "boolean, if set, script will calculate and display account balances in l1 and l2")

	flag.BoolVar(&crosschaintxDeposit, "crosschaintxDeposit", false, "boolean, need to set layer as well. 1 for deposit, 2 for withdraw")
}

func main() {
	flag.Parse()
	// TO DO:ADD A CONDITION TO FORCE THE PROGRAM TO EXIT IN CASE USER PROVIDES NON COMPATIBLE FLAGS
	TxSl, _ := time.ParseDuration(TxSleep)
	strlayer := strconv.Itoa(layer)
	tnEnv, err := godotenv.Read()
	if err != nil {
		fmt.Println(err)
		log.Fatal(err)
	}

	ctrMethods, err := godotenv.Read(".solidityMethods")
	if err != nil {
		fmt.Println(err)
		log.Fatal(err)
	}

	// fmt.Println(ctrMethods["dispatchMessage"])

	ksdir := tnEnv["KEYSTORE"]
	passw0rd := tnEnv["PASSWORD"]
	lOnebridge := tnEnv["L1BRIDGEADDR"]
	lTwobridge := tnEnv["L2BRIDGEADDR"]
	// miner = tnEnv["MINERADDR"]

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

	//fmt.Printf("CLIENT SETUP:\nshowBal: %v\ndoDeposits: %v\ndoTxs: %v\nlayer: %v\nenvironment: %v\nTxCount: %v\n", showBal, doDeposits, doTxs, layer, testEnv, TxCount)

	if showBal {

		bal := GetBalances(_accounts, *ethcl1, *ethcl2, _ctx)
		for _, b := range bal {
			fmt.Printf("account %x has %v funds in l2 and %v funds in l1\n", b.hexaddr, b.layer2Funds, b.layer1Funds)

		}
	}

	if initL2Funds {

		bridgeAddress := common.HexToAddress(lOnebridge)
		bridge, err := zkevml1bridge.NewZkevml1bridge(bridgeAddress, ethcl1)
		if err != nil {
			fmt.Println(err)
			log.Fatal(err)
		}
		zeros = append(zeros, big.NewInt(0))

		for len(zeros) != 0 {
			zeros = nil
			// Generate zkevml1bridge.DispatchMessage inputs, deposit 1/10000 to l2
			disMsgData, si, _ := NewDmsgData(&ks, bridgeAddress, balanceDivisor, _accounts, *ethcl1, _ctx, r, l1ChainId)
			fmt.Printf("account : %x || nonce: %v\n", _accounts[si].Address, disMsgData._nonce)
			if testFuzz {
				disMsgData._data = NewFuzzedData65535()
				addLimit := uint64(68) * uint64(len(disMsgData._data))
				disMsgData._txOpts.GasLimit = disMsgData._txOpts.GasLimit + addLimit
			}
			//Send transaction with generated bind.TransactOpts
			tx, err := bridge.DispatchMessage(disMsgData._txOpts, disMsgData._to, disMsgData._fee, disMsgData._deadline, disMsgData._nonce, disMsgData._data)
			if err != nil {
				fmt.Println(err)
				// log.Fatal(err)
			}

			fmt.Printf("TxHash: %v\n", tx.Hash())
			TxHashes = append(TxHashes, tx.Hash())

			// fmt.Printf("TxCost: %v\n\n\n", tx.Cost())

			errr := ethcl1.SendTransaction(_ctx, tx)
			if errr != nil {
				fmt.Println(errr)
				// log.Fatal(err)
			}

			bal := GetBalances(_accounts, *ethcl1, *ethcl2, _ctx)
			for _, b := range bal {
				if b.layer2Funds.Cmp(big.NewInt(0)) == 0 {
					zeros = append(zeros, b.layer2Funds)
					// fmt.Println("true")
				}

			}

		}
		fmt.Printf("number of transactions sent: %v\n", len(TxHashes))
		fmt.Println(TxHashes)
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

		for ii := 1; ii <= TxCount; ii++ {
			disMsgData, si, _ := NewDmsgData(&ks, bridgeAddress, balanceDivisor, _accounts, *ethcl, _ctx, r, chainId)
			fmt.Printf("account : %x\nDispatchMessageNonce: %v\nTxOptsNonce(This is always the sender account nonce): %v\n", _accounts[si].Address, disMsgData._nonce, disMsgData._txOpts.Nonce)
			//Send transaction with generated bind.TransactOpts
			tx, err := bridge.DispatchMessage(disMsgData._txOpts, disMsgData._to, disMsgData._fee, disMsgData._deadline, disMsgData._nonce, disMsgData._data)
			if err != nil {
				fmt.Println(err)
				// log.Fatal(err)
			}

			fmt.Printf("TxHash: %v\n", tx.Hash())
			TxHashes = append(TxHashes, tx.Hash())

			errr := ethcl.SendTransaction(_ctx, tx)
			if errr != nil {
				fmt.Println(errr)
				// log.Fatal(err)
			}

			time.Sleep(TxSl)
		}
	}

	if doWithDraws {
		strlayer = "2"
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

		bridgeAddress := common.HexToAddress(lTwobridge)
		bridge, err := zkevmmessagedispatcher.NewZkevmmessagedispatcher(bridgeAddress, ethcl)
		if err != nil {
			fmt.Println(err)
			log.Fatal(err)
		}

		for ii := 1; ii <= TxCount; ii++ {
			disMsgData, si, _ := NewDmsgData(&ks, bridgeAddress, balanceDivisor, _accounts, *ethcl, _ctx, r, chainId)
			fmt.Printf("account : %x\nDispatchMessageNonce: %v\nTxOptsNonce(This is always the sender account nonce): %v\n", _accounts[si].Address, disMsgData._nonce, disMsgData._txOpts.Nonce)
			//Send transaction with generated bind.TransactOpts
			tx, err := bridge.DispatchMessage(disMsgData._txOpts, disMsgData._to, disMsgData._fee, disMsgData._deadline, disMsgData._nonce, disMsgData._data)
			if err != nil {
				fmt.Println(err)
				// log.Fatal(err)
			}

			fmt.Printf("TxHash: %v\n %v\n", tx.Hash(), ii)
			TxHashes = append(TxHashes, tx.Hash())

			errr := ethcl.SendTransaction(_ctx, tx)
			if errr != nil {
				fmt.Printf("ERROR: %v\n", errr)
				// log.Fatal(err)
			}

			time.Sleep(TxSl)
		}

	}

	if doTxs {
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

		for ii := 1; ii <= TxCount; ii++ {
			newtxdata, si, _ := NewTxData(_accounts, *ethcl, _ctx, r)
			newtx := NewTx(newtxdata)
			signedTx, err := ks.SignTxWithPassphrase(_accounts[si], passw0rd, newtx, chainId)
			if err != nil {
				fmt.Println(err)
				// log.Fatal(err)
			}

			fmt.Printf("Account Nonce: %v\n", newtxdata._nonce)
			err = ethcl.SendTransaction(_ctx, signedTx)
			if err != nil {
				fmt.Println(err)
				// log.Fatal(err)
			}

			time.Sleep(TxSl)
			fmt.Printf("Sent %v Txs so far\n", ii)
		}
	}

	// if oneDepositNoLoop {
	// 	strlayer = "1"
	// 	ethcl, err := ethclient.Dial(tnEnv[testEnv+"_L"+strlayer])
	// 	if err != nil {
	// 		fmt.Println(err)
	// 		log.Fatal(err)
	// 	}
	// 	chainId, err := ethcl.NetworkID(_ctx)
	// 	if err != nil {
	// 		fmt.Println(err)
	// 		log.Fatal(err)
	// 	}

	// 	bridgeAddress := common.HexToAddress(lOnebridge)
	// 	bridge, err := zkevml1bridge.NewZkevml1bridge(bridgeAddress, ethcl)
	// 	if err != nil {
	// 		fmt.Println(err)
	// 		log.Fatal(err)
	// 	}

	// 	disMsgData, si, _ := NewDmsgData(&ks, bridgeAddress, balanceDivisor, _accounts, *ethcl, _ctx, r, chainId)
	// 	fmt.Printf("account : %x\nDispatchMessageNonce: %v\nTxOptsNonce(This is always the sender account nonce): %v\n", _accounts[si].Address, disMsgData._nonce, disMsgData._txOpts.Nonce)
	// 	if testFuzz {
	// 		disMsgData._data = NewFuzzedData65535()
	// 		addLimit := uint64(68) * uint64(len(disMsgData._data))
	// 		disMsgData._txOpts.GasLimit = disMsgData._txOpts.GasLimit + addLimit
	// 	}
	// 	//Send transaction with generated bind.TransactOpts and fuzzed data if fuzzed is enabled
	// 	tx, err := bridge.DispatchMessage(disMsgData._txOpts, disMsgData._to, disMsgData._fee, disMsgData._deadline, disMsgData._nonce, disMsgData._data)
	// 	if err != nil {
	// 		fmt.Println(err)
	// 		// log.Fatal(err)
	// 	}

	// 	fmt.Printf("TxHash: %v\n", tx.Hash())
	// 	TxHashes = append(TxHashes, tx.Hash())

	// 	errr := ethcl.SendTransaction(_ctx, tx)
	// 	if errr != nil {
	// 		fmt.Println(errr)
	// 		// log.Fatal(err)
	// 	}
	// }

	if oneWithDrawNoLoop {
		strlayer = "2"
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

		bridgeAddress := common.HexToAddress(lTwobridge)
		bridge, err := zkevml1bridge.NewZkevml1bridge(bridgeAddress, ethcl)
		if err != nil {
			fmt.Println(err)
			log.Fatal(err)
		}

		disMsgData, si, _ := NewDmsgData(&ks, bridgeAddress, balanceDivisor, _accounts, *ethcl, _ctx, r, chainId)
		fmt.Printf("account : %x\nDispatchMessageNonce: %v\nTxOptsNonce(This is always the sender account nonce): %v\n", _accounts[si].Address, disMsgData._nonce, disMsgData._txOpts.Nonce)
		if testFuzz {
			disMsgData._data = NewFuzzedData65535()
			addLimit := uint64(68) * uint64(len(disMsgData._data))
			disMsgData._txOpts.GasLimit = disMsgData._txOpts.GasLimit + addLimit
		}
		//Send transaction with generated bind.TransactOpts
		tx, err := bridge.DispatchMessage(disMsgData._txOpts, disMsgData._to, disMsgData._fee, disMsgData._deadline, disMsgData._nonce, disMsgData._data)
		if err != nil {
			fmt.Println(err)
			// log.Fatal(err)
		}

		fmt.Printf("TxHash: %v\n", tx.Hash())
		TxHashes = append(TxHashes, tx.Hash())

		errr := ethcl.SendTransaction(_ctx, tx)
		if errr != nil {
			fmt.Println(errr)
			// log.Fatal(err)
		}
	}

	if crosschaintxDeposit && strlayer == "1" {
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
		for ii := 1; ii <= TxCount; ii++ {
			NewCrossChainTxData, si, ri := NewTxData(_accounts, *ethcl, _ctx, r)
			ccdata := EncodeFunction(
				"dispatchMessage",
				ctrMethods["dispatchMessage"],
				common.Bytes2Hex(_accounts[ri].Address.Bytes()),
				"0",
				"0xffffffffffffffff",
				strconv.FormatUint(NewCrossChainTxData._nonce, 10),
				"0x",
			)
			fmt.Println(ccdata)
			NewCrossChainTxData._data = []byte(ccdata)
			tx := NewCrossChainTx(bridgeAddress, NewCrossChainTxData)

			signedTx, err := ks.SignTxWithPassphrase(_accounts[si], passw0rd, tx, chainId)
			if err != nil {
				fmt.Println(err)
				// log.Fatal(err)
			}

			err = ethcl.SendTransaction(_ctx, signedTx)
			if err != nil {
				fmt.Println(err)
				// log.Fatal(err)
			}

		}

		// jscommand := "node encodeData.js " + ctrMethods["dispatchMessage"] + "" + toAddr + "" + fee + "" + deadline + "" + nonce + "" + calldata
		// jsparts := strings.Fields(jscommand)
		// jsdata, err := exec.Command(jsparts[0], jsparts[1:]...).Output()
		// if err != nil {
		// 	panic(err)
		// }

		// jsoutput := string(jsdata)
		// fmt.Printf("input: %v\n\n\n\n", jsoutput)
	}

	// if testFuzz {
	// 	NewFuzzedData255()
	// 	// fmt.Println(dd)
	// }
	//Set of dummy print statements to avoid unused variables error
	// fmt.Println("DUMMY PRINTS:")
}
