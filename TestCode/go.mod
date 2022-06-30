module zkevmchaintest

go 1.18

require (
	github.com/ethereum/go-ethereum v1.10.18
	github.com/google/gofuzz v1.2.0
	github.com/joho/godotenv v1.4.0
)

require (
	github.com/StackExchange/wmi v0.0.0-20180116203802-5d049714c4a6 // indirect
	github.com/btcsuite/btcd/btcec/v2 v2.2.0 // indirect
	github.com/deckarep/golang-set v1.8.0 // indirect
	github.com/decred/dcrd/dcrec/secp256k1/v4 v4.0.1 // indirect
	github.com/go-ole/go-ole v1.2.1 // indirect
	github.com/go-stack/stack v1.8.0 // indirect
	github.com/google/uuid v1.2.0 // indirect
	github.com/gorilla/websocket v1.4.2 // indirect
	github.com/rjeczalik/notify v0.9.1 // indirect
	github.com/shirou/gopsutil v3.21.4-0.20210419000835-c7a38de76ee5+incompatible // indirect
	github.com/tklauser/go-sysconf v0.3.5 // indirect
	github.com/tklauser/numcpus v0.2.2 // indirect
	golang.org/x/crypto v0.0.0-20220525230936-793ad666bf5e // indirect
	golang.org/x/sys v0.0.0-20220520151302-bc2c85ada10a // indirect
	gopkg.in/natefinch/npipe.v2 v2.0.0-20160621034901-c1b8fa8bdcce // indirect
	rogchap.com/v8go v0.7.0 // indirect
)

replace testcode v1.0.0 => ./testcode

replace fuzz v1.0.0 => ./fuzz

replace zkevmmessagedispatcher v1.0.0 => ./zkevmmessagedispatcher

// replace fuzzers v1.0.0 => ./fuzzers

replace zkevmbridgeevents v1.0.0 => ./zkevmbridgeevents

replace zkevmmagicnumbers v1.0.0 => ./zkevmmagicnumbers

replace zkevml1bridge v1.0.0 => ./zkevml1bridge

replace zkevmutils v1.0.0 => ./zkevmutils

replace zkevmmessagedelivererbase v1.0.0 => ./zkevmmessagedelivererbase

replace zkevmstorage v1.0.0 => ./zkevmstorage

replace izkevmmessagedelivererbase v1.0.0 => ./izkevmmessagedelivererbase

replace izkevmmessagedispatcher v1.0.0 => ./izkevmmessagedispatcher

replace patriciavalidator v1.0.0 => ./patriciavalidator

replace izkevmmessagedelivererwithproof v1.0.0 => ./izkevmmessagedelivererwithproof
