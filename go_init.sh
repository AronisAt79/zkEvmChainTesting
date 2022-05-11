#!/bin/bash
set -e
set -x

go mod init zkevmchaintest
go get -u github.com/ethereum/go-ethereum
cd /go/pkg/mod/github.com/ethereum/go-ethereum\@v1.10.17/
make devtools 
