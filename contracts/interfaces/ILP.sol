// SPDX-License-Identifier: GPL-2.0-or-later

interface ILP {
    function provideLiquidity(
        address poolAdress,
        uint64 width,
        uint64 amount0,
        uint64 amount1
    ) external payable returns (
        uint160 sqrtPrice, 
        uint256 price, 
        uint160 sqrtPA, 
        uint160 sqrtPB,
        int24 pATick,
        int24 pBTick,
        int24 tick
    );
}