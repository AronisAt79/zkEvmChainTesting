package main

import (
	"context"
	"fmt"
	"math/big"
	rand "math/rand"
	"os/exec"
	"strings"
	"zkevmchaintest/fuzz"

	// crand "crypto/rand"
	ethereum "github.com/ethereum/go-ethereum"

	"github.com/ethereum/go-ethereum/accounts"
	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/accounts/keystore"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/common/hexutil"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/ethclient"
	"github.com/ethereum/go-ethereum/params"
)

type ctx context.Context

type accs []accounts.Account

type netw0rks []netw0rk

type netw0rk struct {
	chainID *big.Int
	layer   string
	_url    string
}

type addr map[string]string

type txData struct {
	_to       common.Address
	_nonce    uint64
	_amount   *big.Int
	_gasLimit uint64
	_gasPrice *big.Int
	_data     []byte
}

type balance struct {
	hexaddr     common.Address
	layer1Funds *big.Int
	layer2Funds *big.Int
}

type balances []balance

type dMsgData struct {
	_txOpts *bind.TransactOpts
	_to     common.Address
	// fuzz fee
	_fee *big.Int
	// fuzz deadline
	_deadline *big.Int
	_nonce    *big.Int
	// fuzz data >> in progress
	_data []byte
}

func NewDmsgData(ks *keystore.KeyStore, nonceAddr common.Address, v int64, ac accs, ec ethclient.Client, c ctx, r *rand.Rand, chainid *big.Int) (dMsgData, int, int) {
	si := r.Intn(len(ac)) // sender's index (from accs slice)
	sender := ac[si]
	ri := r.Intn(len(ac)) // receiver's index (from accs slice)
	receiver := ac[si]
	bal := CalculateFunds(ec, c, sender)
	txOpts, _ := bind.NewKeyStoreTransactorWithChainID(ks, sender, chainid)
	_sendernonce, _ := ec.NonceAt(c, sender.Address, nil)
	senderNonce := big.NewInt(int64(_sendernonce))
	nonceAddress := nonceAddr
	Nonce_uint64, _ := ec.NonceAt(c, nonceAddress, nil)
	Nonce := big.NewInt(int64(Nonce_uint64))

	dispMsgNonce, _ := hexutil.DecodeBig("0xffffff")

	egl, _ := ec.EstimateGas(c, ethereum.CallMsg{
		// To:   &contractAddress, >> returns: Served eth_estimateGas err="execution reverted"
		To:   &sender.Address,
		Data: []byte{0},
	})

	txOpts.Value = new(big.Int).Div(bal, big.NewInt(v))
	txOpts.Nonce = senderNonce
	txOpts.GasLimit = uint64(float64(egl) * 10)
	txOpts.GasPrice, _ = ec.SuggestGasPrice(c)

	fmt.Printf("DUMMY PRINT TO AVOID VARIABLE NOT USED ERROR: %v %v\n", Nonce, dispMsgNonce)

	return dMsgData{
			txOpts,
			receiver.Address,
			big.NewInt(100 * params.GWei),
			big.NewInt(10000000000),
			// senderNonce,
			dispMsgNonce,
			// Nonce,
			[]byte{
				0x0,
			},
		},
		si,
		ri
}

func LoadAccounts(ksDir string) (accs, keystore.KeyStore) {
	ks := keystore.NewKeyStore(ksDir, keystore.StandardScryptN, keystore.StandardScryptP)
	return ks.Accounts(), *ks
}

func CalculateFunds(ec ethclient.Client, c ctx, a accounts.Account) *big.Int {
	bal, _ := ec.BalanceAt(c, a.Address, nil)
	return bal
}

func NewTxData(ac accs, ec ethclient.Client, c ctx, r *rand.Rand) (txData, int, int) {
	si := r.Intn(len(ac)) // sender's index (from accs slice)
	sender := ac[si]
	ri := r.Intn(len(ac)) // receiver's index (from accs slice)
	n0nce, _ := ec.NonceAt(c, sender.Address, nil)
	receiver := ac[ri]
	// _gasPrice, _ := ec.SuggestGasPrice(c)
	return txData{
			receiver.Address,
			n0nce,
			big.NewInt(1 * params.GWei),
			uint64(21000),
			big.NewInt(1 * params.GWei),
			// _gasPrice,
			[]byte{},
		},
		si,
		ri
}

func NewTx(newtxdata txData) *types.Transaction {
	tx := types.NewTransaction(
		newtxdata._nonce,
		newtxdata._to,
		newtxdata._amount,
		newtxdata._gasLimit,
		newtxdata._gasPrice,
		newtxdata._data,
	)
	return tx
}

func GetBalances(ac accs, ec1 ethclient.Client, ec2 ethclient.Client, c ctx) balances {
	_balances := balances{}
	for _, _acc := range ac {
		bal1 := CalculateFunds(ec1, c, _acc)
		bal2 := CalculateFunds(ec2, c, _acc)

		_balance := balance{
			_acc.Address,
			bal1,
			bal2,
		}
		_balances = append(_balances, _balance)
	}
	return _balances
}

// Functions for generating fuzzed inputs

//

// Generates a []byte of random/fuzzed size and elements
func NewFuzzedData65535() []byte {
	var ddata []byte
	var myByte byte
	f := fuzz.New()
	// fuzz the slice length
	var sliceCount uint16
	f.Fuzz(&sliceCount)
	fmt.Printf("creating a random []bytes with %v elements\n", sliceCount)
	for ii := 1; ii <= int(sliceCount); ii++ {
		f.Fuzz(&myByte)
		ddata = append(ddata, myByte)
	}

	// fmt.Println(ddata)
	return ddata
}

func EncodeFunction(methName, methSig, receiver, fee, deadline, nonce, calldata string) string {
	jscommand := "node encodeData.js " + methName + " " + methSig + " " + receiver + " " + fee + " " + deadline + " " + nonce + " " + calldata
	jsparts := strings.Fields(jscommand)
	jsdata, err := exec.Command(jsparts[0], jsparts[1:]...).Output()
	if err != nil {
		fmt.Println(err)
	}

	jsoutput := string(jsdata)
	return jsoutput
}

//////////////////////////////////////////////////////////

// func NewCrossChainTxData(ac accs, ec ethclient.Client, c ctx, r *rand.Rand) (txData int int){
// 	si := r.Intn(len(ac)) // sender's index (from accs slice)
// 	sender := ac[si]
// 	ri := r.Intn(len(ac)) // receiver's index (from accs slice)
// 	n0nce, _ := ec.NonceAt(c, sender.Address, nil)
// 	receiver := ac[ri]
// 	return txData{
// 		receiver.Address,
// 			n0nce,
// 			big.NewInt(1 * params.GWei),
// 			uint64(21000),
// 			big.NewInt(1 * params.GWei),
// 			// _gasPrice,
// 			[]byte{},
// 	},
// 	si,
// 	ri
// }

func NewCrossChainTx(contractaddr common.Address, newtxdata txData) *types.Transaction {
	tx := types.NewTransaction(
		newtxdata._nonce,
		contractaddr,
		newtxdata._amount,
		newtxdata._gasLimit,
		newtxdata._gasPrice,
		newtxdata._data,
	)
	return tx
}

//////////////////////////////////////////////////////////
