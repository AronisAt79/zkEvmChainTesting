// SPDX-License-Identifier: MIT

pragma solidity =0.8.13;

contract Check {
    function checkMulMod(
        uint256 x,
        uint256 y,
        uint256 m
    ) external pure returns (uint256 r) {
        assembly {
            r := mulmod(x, y, m)
        }
    }
}
