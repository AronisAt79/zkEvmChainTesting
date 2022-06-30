#!/bin/bash
#
set -e
set -x

wdir=$(pwd)
user=$(id -un 1000)

git clone https://github.com/google/gofuzz $wdir/TestCode/fuzz
# ;)
find $wdir/TestCode/fuzz ! -path $wdir/TestCode/fuzz ! -name 'fuzz.go' -exec rm -rf {} \; > /dev/null 2>&1 || true

docker run -dit -v $wdir:/Code --name gotest golang
docker exec --workdir /Code/TestCode gotest /Code/go_init.sh

sudo chown -R $user:$user $wdir/*

for i in `find $wdir/TestCode -mindepth 1 -maxdepth 1 -type d -exec basename {} \;`; do
    pack=${i,,}
    echo "replace $pack v1.0.0 => ./${i,,}" >> $wdir/TestCode/go.mod
    #echo "replace $pack v1.0.0 => ./$i" >> $wdir/go.mod
done

docker exec --workdir /Code/TestCode gotest go mod tidy
docker exec --workdir /Code/TestCode gotest go build .
docker rm -f gotest

sudo chown -R $user:$user $wdir/*
sudo apt install nodejs npm -y
npm install ethers
