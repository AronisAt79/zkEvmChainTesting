// SPDX-License-Identifier: MIT

pragma solidity =0.8.13;

contract Check3 {
    struct Len {
        uint256 l;
    }

    function checkBatchYul(Len calldata l) external returns (uint256 r) {
        assembly {
            let len := calldataload(4)
            for {
                let i := 0
            } lt(i, len) {
                i := add(i, 1)
            } {
                r := mulmod(5, 10, 26)
            }
        }
    }
}