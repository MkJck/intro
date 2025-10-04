// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/UniswapV3.sol";
import "./interfaces/ILP.sol";
import "hardhat/console.sol";

contract LP is ILP {
    INonfungiblePositionManager immutable nfpManager;

    constructor(address nfpManagerAddress) {
        nfpManager = INonfungiblePositionManager(nfpManagerAddress);
    }

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
        int24 curTick
    ) {
        checkInputData(width, amount0, amount1);

        IUniswapV3Pool pool = IUniswapV3Pool(poolAdress);

        IERC20 token0 = IERC20(pool.token0());
        IERC20 token1 = IERC20(pool.token1());

        {
            (uint160 sqrtPriceX96, int24 tick, , , , , ) = pool.slot0();
            curTick = tick;
            sqrtPrice = (sqrtPriceX96 * 10 ** 6) / 2 ** 96; // TODO: fix decimals hardcoding
            price = TickMath.getPriceBySqrtRatio(sqrtPriceX96, 12);

            if (amount0 == 0) {
                (sqrtPA, sqrtPB) = computeBordersForFullToken1Asset(
                    width,
                    sqrtPrice
                );
            } else if (amount1 == 0) {
                (sqrtPA, sqrtPB) = computeBordersForFullToken0Asset(
                    width,
                    sqrtPrice
                );
            } else {
                (sqrtPA, sqrtPB) = computeBordersForGeneralCase(
                    width,
                    amount0,
                    amount1,
                    sqrtPrice,
                    price
                );
            }
        }
        
        {
            uint160 sqrtPAX96 = sqrtPA * 2 ** 96 / 10 ** 6;
            uint160 sqrtPBX96 = sqrtPB * 2 ** 96 / 10 ** 6;

            (pATick, pBTick) = computeTicks(
                pool.tickSpacing(),
                sqrtPAX96,
                sqrtPBX96       
            );
        }        
        
// Uncomment to transfer funds to the liquidity pool:

        // token0.transferFrom(msg.sender, address(this), amount0);
        // token1.transferFrom(msg.sender, address(this), amount1);

        // token0.approve(address(nfpManager), amount0);
        // token1.approve(address(nfpManager), amount1);

        // nfpManager.mint(
        //     INonfungiblePositionManager.MintParams(
        //         address(token0),
        //         address(token1),
        //         pool.fee(),
        //         pATick,
        //         pBTick,
        //         amount0,
        //         amount1,
        //         0,
        //         0,
        //         msg.sender,
        //         block.timestamp
        //     )
        // );
    }

    function computeTicks(
        int24 tickSpacing,
        uint160 sqrtPAX96,
        uint160 sqrtPBX96
    ) private pure returns (int24 pATick, int24 pBTick) {
        int24 pATickExact = TickMath.getTickAtSqrtRatio(sqrtPAX96);
        int24 pBTickExact = TickMath.getTickAtSqrtRatio(sqrtPBX96);
        pATick = (pATickExact / tickSpacing) * tickSpacing;
        pATick -= tickSpacing;
        
        pBTick = (pBTickExact / tickSpacing) * tickSpacing;
        pBTick += tickSpacing;
    }

    function computeBordersForFullToken1Asset(
        uint64 width,
        uint160 sqrtPrice
    ) private pure returns (uint160 sqrtPA, uint160 sqrtPB) {
        sqrtPB = sqrtPrice;
        sqrtPA = SafeCast.toUint160(
            FullMath.mulDiv(sqrtPrice, sqrt(10000 - width), sqrt(10000 + width))
        );
    }

    function computeBordersForFullToken0Asset(
        uint64 width,
        uint160 sqrtPrice
    ) private pure returns (uint160 sqrtPA, uint160 sqrtPB) {
        sqrtPA = sqrtPrice;
        sqrtPB = SafeCast.toUint160(
            FullMath.mulDiv(sqrtPrice, sqrt(10000 + width), sqrt(10000 - width))
        );
    }

    function computeBordersForGeneralCase(
        uint64 width,
        uint64 amount0,
        uint64 amount1,
        uint160 sqrtPrice,
        uint256 price
    ) private pure returns (uint160 sqrtPA, uint160 sqrtPB) {
        uint256 sqrtPANumerator = computeSqrtPANumerator(
            width,
            amount0,
            amount1,
            sqrtPrice,
            price
        );

        uint256 sqrtPADenominator = FullMath.mulDiv(
            2 * amount0 * sqrtPrice,
            sqrt(10000 + width),
            sqrt(10000 - width)
        );

        sqrtPA = SafeCast.toUint160(
            FullMath.mulDiv(sqrtPANumerator, 1, sqrtPADenominator)
        );

        sqrtPB = 
            SafeCast.toUint160(
                FullMath.mulDiv(sqrtPA, sqrt(10000 + width), sqrt(10000 - width))
            );
    }

    function checkInputData(
        uint64 width,
        uint64 amount0,
        uint64 amount1
    ) private pure {
        require(width > 10000, "Invalid width: the value must be greater than 10,000.");
        require(
            amount0 >= 0,
            "Invalid amount0: the value must be greater than or equal to zero."
        );
        require(
            amount1 >= 0,
            "Invalid amount1: the value must be greater than or equal to zero."
        );
        require(
            (amount0 != 0) || (amount1 != 0),
            "Invalid amounts: both amount1 and amount2 must not be zeros."
        );
    }

    function computeSqrtPANumerator(
        uint256 width,
        uint256 amount0,
        uint256 amount1,
        uint160 sqrtPrice,
        uint256 price
    ) private pure returns (uint256 numerator) {
        uint256 firstPartOfDiscriminant = amount1 ** 2 + (amount0 ** 2) * (price ** 2) 
            - 2 * amount0 * amount1 * price;

        uint256 discriminant = FullMath.mulDiv(
            firstPartOfDiscriminant,
            10000 + width,
            10000 - width
        ) +
            FullMath.mulDiv(
                4 * amount0 * price * amount1,
                sqrt(10000 + width),
                sqrt(10000 - width)
            );

        numerator =
            FullMath.mulDiv(
                amount0 * price - amount1,
                sqrt(10000 + width),
                sqrt(10000 - width)
            ) +
            sqrt(discriminant);

        if (numerator < 0) { 
            numerator =
                FullMath.mulDiv(
                    amount0 * sqrtPrice - amount1,
                    sqrt(10000 + width),
                    sqrt(10000 - width)
                ) -
                sqrt(discriminant);
            require(numerator >= 0, "No solutions");
        }
    }

    function sqrt(uint x) public pure returns (uint y) {
        uint z = (x + 1) / 2;
        y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
    }
}