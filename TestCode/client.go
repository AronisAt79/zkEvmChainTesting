package main

import (
	// "os"

	"context"
	"flag"
	"fmt"
	"log"
	"math/big"
	rand "math/rand"
	"os"
	"strconv"
	"time"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/common/hexutil"
	"github.com/joho/godotenv"
)

var showBalances bool
var tnEnv map[string]string
var zeros []*big.Int
var doTxs bool
var layer int
var testEnv string
var TxCount int
var crosschain bool
var balanceDivisor int64
var methodName string
var testFuzz bool
var TxSleep string

/////////////////////////////////////////////////////////////
// Declare variables to broaden scope outside of conditionals
/////////////////////////////////////////////////////////////
var txdata []byte
var fdata []byte
var toAddr common.Address
var ctrMethods map[string]string
var bridgeaddress common.Address
var abiencoding string
var internalCallData string

func init() {
	flag.StringVar(&TxSleep, "TxSleep", "1s", "select number of seconds to pause inbetween Txs || example: -TxSleep='3s'")
	flag.BoolVar(&testFuzz, "testFuzz", false, "boolean, if set, script will calculate and display account balances in l1 and l2")
	flag.BoolVar(&showBalances, "showBalances", false, "boolean")
	flag.BoolVar(&doTxs, "doTxs", false, "boolean, if set, script will run simple Txs on selected layer, until exited")
	flag.IntVar(&layer, "layer", 0, "select layer, must be 1 or 2 - only relevant when doTxs is TRUE")
	flag.StringVar(&testEnv, "testEnv", "REPLICA", "select environment as test target")
	flag.IntVar(&TxCount, "TxCount", 1, "select number of Txs to execute")
	flag.Int64Var(&balanceDivisor, "balanceDivisor", 1000000, "int64, amount to transfer equals balance/balanceDivisor")
	flag.BoolVar(&crosschain, "crosschain", false, "boolean, indicates id this is a crosschain operation, ie deposit (layer=1) or withdraw (layer=2)")
	flag.StringVar(&methodName, "methodName", "", "select target solidity method, mandatory if crosschain is set")
}

func main() {
	flag.Parse()
	TxSl, _ := time.ParseDuration(TxSleep)
	if doTxs && layer != 1 && layer != 2 {
		fmt.Println("Invalid cli inputs. Must set layer to 1 or 2")
		os.Exit(1)
	}

	if crosschain && methodName == "" {
		fmt.Println("Invalid cli inputs. Must set methodName for crosschain operation")
		os.Exit(1)
	}

	strlayer := strconv.Itoa(layer)
	tnEnv, err := godotenv.Read()
	if err != nil {
		fmt.Println(err)
		log.Fatal(err)
	}

	ksdir := tnEnv["KEYSTORE"]
	passw0rd := tnEnv["PASSWORD"]

	_accounts, ks := LoadAccounts(ksdir)
	_ctx := context.Background()

	for _, account := range _accounts {
		ks.Unlock(account, passw0rd)
	}

	if crosschain {
		// lOnebridge := tnEnv["L1BRIDGEADDR"]
		// lTwobridge := tnEnv["L2BRIDGEADDR"]

		ctrMethods, err = godotenv.Read(".solidityMethods")
		if err != nil {
			fmt.Println(err)
			log.Fatal(err)
		}

	}

	if showBalances {
		ethcl1, _ := InstantiateEthClient(_ctx, testEnv, "1", tnEnv)
		ethcl2, _ := InstantiateEthClient(_ctx, testEnv, "2", tnEnv)
		bal := GetBalances(_accounts, *ethcl1, *ethcl2, _ctx)
		for _, b := range bal {
			fmt.Printf("account %x has %v funds in l2 and %v funds in l1\n", b.hexaddr, b.layer2Funds, b.layer1Funds)

		}
	}

	if doTxs {
		source := rand.NewSource(time.Now().UnixNano())
		r := rand.New(source)
		ethcl, chainid := InstantiateEthClient(_ctx, testEnv, strlayer, tnEnv)
		for ii := 1; ii <= TxCount; ii++ {
			senderaddr, receiveraddr, si, _ := ShuffleAccounts(_accounts, r)
			nonce := CalcAccNonce(senderaddr, *ethcl, _ctx)
			if crosschain {
				bridgeaddress = common.HexToAddress(tnEnv["L"+strlayer+"BRIDGEADDR"])
				toAddr = bridgeaddress
				// fdatastring := EncodeFunction(
				// 	methodName,
				// 	ctrMethods[methodName],
				// 	common.Bytes2Hex(receiveraddr.Bytes()),
				// 	"0",
				// 	"0xffffffffffffffff",
				// 	strconv.FormatUint(nonce, 10),
				// 	"0x",
				// )
				if testFuzz {
					internalCallDataBytes := NewFuzzedData65535()
					internalCallData = hexutil.Encode(internalCallDataBytes)
				} else {
					internalCallData = "0x"
				}
				newfuncinputs := NewSolidityFuncInputs(
					nonce,
					receiveraddr,
					methodName,
					ctrMethods[methodName],
					"0",
					"0xffffffffffffffff",
					internalCallData,
				)

				abiencoding := EncodeFunction(newfuncinputs)
				abiencodingbytes, _ := hexutil.Decode(abiencoding)
				fdata = abiencodingbytes
				txdata = fdata

			} else {
				toAddr = receiveraddr
				txdata = []byte{0}
				fdata = []byte{0}
			}

			payload := txdata

			// toAddr = common.HexToAddress("a499d680c1854e15fd009cc8c84b68f545e46d34")
			amount := CalculateAmount(CalculateFunds(*ethcl, _ctx, senderaddr), balanceDivisor)
			gaslimit, payloadLength := EstimateGasLimit(senderaddr, *ethcl, payload, _ctx)
			gasprice := EstimateGasPrice(*ethcl, _ctx)

			gasLimitADjusted := AddGasLimit(gaslimit, payloadLength)
			fmt.Printf("gasLimitADjusted: %v\n", gasLimitADjusted)
			gasLimitADjustedUsed := uint64(1000000)
			fmt.Printf("gasLimitADjustedUsed: %v\n", gasLimitADjustedUsed)
			newtxdata := NewTxData(toAddr, *ethcl, _ctx, nonce, amount, gasLimitADjustedUsed, gasprice, txdata)
			tx := NewTx(newtxdata)
			signedTx, err := ks.SignTxWithPassphrase(_accounts[si], passw0rd, tx, chainid)
			fmt.Printf("TxHash: %v\n", signedTx.Hash())
			if err != nil {
				fmt.Println(err)
				// log.Fatal(err)
			}

			err = ethcl.SendTransaction(_ctx, signedTx)
			if err != nil {
				fmt.Println(err)
				// log.Fatal(err)
			}

			time.Sleep(TxSl)
		}

	}

}
