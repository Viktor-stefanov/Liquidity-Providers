// SPDX-License-Identifier: No-License
pragma solidity 0.8.17;

import "./libraries/LibFacet.sol";
import "hardhat/console.sol";

contract DiamondInit {
    function ethToERCInit(
        address[] memory _tokenPools,
        string[] memory _tokenSymbols,
        address _priceFeed,
        uint256 _feeDivisor,
        uint256 _precisionMult
    ) public {
        LibFacet.FacetStorage storage fs;
        bytes32 position = LibFacet.FACET_STORAGE_POSITION;
        assembly {
            fs.slot := position
        }

        fs.precisionMult = 10**_precisionMult;
        fs.feeDivisor = (10**18 * 100) / _feeDivisor;
        fs.priceFeed = PriceFeed(_priceFeed);
        for (uint256 i = 0; i < _tokenPools.length; i += 2) {
            address token1Contract = _tokenPools[i];
            address token2Contract = _tokenPools[i + 1];
            string memory pair = string.concat(
                _tokenSymbols[i],
                "/",
                _tokenSymbols[i + 1]
            );

            fs.pools.push(pair);

            fs.tokenPools[pair] = LibFacet.PairPool(
                _tokenSymbols[i],
                _tokenSymbols[i + 1],
                token1Contract,
                token2Contract,
                0,
                0,
                0,
                0,
                0,
                0,
                true
            );
        }
    }
}
