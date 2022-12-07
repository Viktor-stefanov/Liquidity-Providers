// SPDX-License-Identifier: No-License
pragma solidity 0.8.17;

import "../PriceFeed.sol";

library LibFacet {
    bytes32 constant FACET_STORAGE_POSITION =
        keccak256("diamond.standart.facet.storage");

    struct LiquidityShare {
        uint256 t1Amount;
        uint256 t2Amount;
    }

    struct PairPool {
        string token1;
        string token2;
        address token1Con;
        address token2Con;
        uint256 token1Amount;
        uint256 token2Amount;
        uint256 token1Seed;
        uint256 token2Seed;
        uint256 t1Fees;
        uint256 t2Fees;
        bool created;
    }

    struct FacetStorage {
        PriceFeed priceFeed;
        mapping(string => PairPool) tokenPools;
        mapping(string => mapping(address => LiquidityShare)) liquidityShares;
        mapping(string => address[]) liquidityProviders;
        string[] pools;
        uint256 feeDivisor;
        uint256 precisionMult;
        LiquidityShare share;
        PairPool pool;
    }

    function facetStorage() internal pure returns (FacetStorage storage fs) {
        bytes32 position = FACET_STORAGE_POSITION;
        assembly {
            fs.slot := position
        }
    }
}
