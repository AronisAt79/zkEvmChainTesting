# zkEvmChainTesting

## Prerequisites: 
 - a linux machine with docker engine installed

## Instructions:

### 1. Setup
```
    cd into zkEvmChainTesting directory &
    run setup.sh
```
### 2. Test execution
```
  #docker exec --workdir /Code/TestCode -it gotest bash

  #go run . -h to see the possible arguments
```
    or 
```
 Navigate to zkEvmChainTesting/TestCode on host machine and run
 ./zkevmchaintest -h 
 
 If this is the prefered approach, in case of local code changes, rerun
 
 #docker exec --workdir /Code/TestCode gotest go build .
```
