// SPDX-License-Identifier: MIT

pragma solidity =0.8.13;

contract Check2 {
    struct Input {
        uint256 x;
        uint256 y;
        uint256 m;
        uint256 l;
    }

    function checkMulMod(
        uint256 x,
        uint256 y,
        uint256 m
    ) public pure returns (uint256 r) {
        assembly {
            r := mulmod(x, y, m)
        }
    }

    function checkBatch(Input calldata io) external {
        for (uint256 i = 0; i < io.l; i++) {
            checkMulMod(io.x, io.y, io.m);
        }
    }
}