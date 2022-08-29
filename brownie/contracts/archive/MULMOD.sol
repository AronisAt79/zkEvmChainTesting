// SPDX-License-Identifier: MIT

pragma solidity =0.8.13;

contract Check {
    struct Input {
        uint256 x;
        uint256 y;
        uint256 m;
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

    function checkBatch(Input[] calldata io) external {
        for (uint256 i = 0; i < io.length; i++) {
            checkMulMod(io[i].x, io[i].y, io[i].m);
        }
    }
}
