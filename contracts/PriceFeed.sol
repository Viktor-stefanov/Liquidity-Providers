// SPDX-License-Identifier: no-license
pragma solidity 0.8.17;
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV2V3Interface.sol";

contract PriceFeed {
    mapping(address => AggregatorV3Interface) priceFeeds;

    constructor(
        address[] memory _tokenContracts,
        address[] memory _tokenAggregators
    ) {
        require(
            _tokenContracts.length == _tokenAggregators.length,
            "Mismatch in amount of token contracts and token aggregators."
        );

        for (uint256 i = 0; i < _tokenContracts.length; i++) {
            address tokenContract = _tokenContracts[i];
            address tokenAggregator = _tokenAggregators[i];
            priceFeeds[tokenContract] = AggregatorV3Interface(tokenAggregator);
        }
    }

    function getPrice(address _tokenContract) public view returns (uint256) {
        (, int256 price, , , ) = priceFeeds[_tokenContract].latestRoundData();
        return uint256(price);
    }
}
