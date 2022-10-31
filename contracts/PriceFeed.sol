// SPDX-License-Identifier: no-license
pragma solidity 0.8.17;
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV2V3Interface.sol";

contract PriceFeed {
    mapping(address => AggregatorV3Interface) priceFeeds;

    function addPriceAggregator(
        address _tokenContract,
        address _tokenAggregator
    ) external {
        priceFeeds[_tokenContract] = AggregatorV3Interface(_tokenAggregator);
    }

    function getPrice(address _tokenContract) public view returns (int256) {
        (, int256 price, , , ) = priceFeeds[_tokenContract].latestRoundData();
        return price;
    }
}
