// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/UniswapV3.sol";
import "./interfaces/ILP.sol";
import "hardhat/console.sol";


contract Intro is ILP {
    INonfungiblePositionManager immutable nfpManager;

    constructor(address nfpManagerAddress) {
        nfpManager = INonfungiblePositionManager(nfpManagerAddress);
    }

}