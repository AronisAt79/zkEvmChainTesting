#!/bin/bash
set -e
set -x

wdir=$(pwd)
user=$(id -un 1000)
#sudo chown -R $user:$user *

git clone https://github.com/appliedzkp/zkevm-chain.git

docker run -v $wdir/zkevm-chain/contracts:/sources ethereum/solc:stable --abi /sources/ZkEvmL1Bridge.sol -o /sources/build
docker run -dit -v $wdir:/Code --name gotest golang
docker exec --workdir /Code/TestCode gotest /Code/go_init.sh  

sudo chown -R $user:$user $wdir/*

cd $wdir/zkevm-chain/contracts/build/

for i in `ls -p`; do
    outfile=$(echo $i | sed 's/.abi/.go/g')
    outfilel=${outfile,,}
    n=$(echo ${i} | sed 's/\.[^ ]*/ /g')
    nl=${n,,}
    nf=$(echo "$wdir/TestCode/${nl}")
    mkdir -p $nf
    docker exec --workdir /Code/zkevm-chain/contracts/build/ gotest abigen --abi $i -pkg $nl --type $nl --out $outfilel
    docker exec --workdir /Code/TestCode gotest mkdir -p $nl 
    docker exec --workdir /Code/zkevm-chain/contracts/build/ gotest cp $outfilel /Code/TestCode/$nl
done

for i in `find $wdir/TestCode -type d -exec basename {} \;`; do
    pack=${i,,}
    echo "replace $pack v1.0.0 => ./${i,,}" >> $wdir/TestCode/go.mod
    #echo "replace $pack v1.0.0 => ./$i" >> $wdir/go.mod
done

docker exec --workdir /Code/TestCode gotest go mod tidy

sudo chown -R $user:$user $wdir/*
