// SPDX-License-Identifier: no-license
pragma solidity 0.8.17;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "hardhat/console.sol";
import "./PriceFeed.sol";

contract EthToUsdc is ERC20 {
    PriceFeed priceFeed;
    ERC20 usdcContract;
    uint256 ethPool;
    uint256 tokenPool;

    constructor(address _usdcContract, address _priceFeed)
        payable
        ERC20("EthToUsdc", "ETUC")
    {
        usdcContract = ERC20(_usdcContract);
        priceFeed = PriceFeed(_priceFeed);
    }

    function deposit(uint256 tokensAmount) external payable {
        require(
            usdcContract.balanceOf(msg.sender) >= tokensAmount,
            "Insufficient ERC20 funds."
        );

        console.log(address(usdcContract));
        uint256 usdcPrice = uint256(priceFeed.getPrice(address(usdcContract)));
        uint256 ethPrice = uint256(
            priceFeed.getPrice(0xB06c856C8eaBd1d8321b687E188204C1018BC4E5)
        );

        // target amount to deposit  usdc: ethPrice/usdcPrice * usdcIn
        uint256 usdcAmount = (ethPrice / usdcPrice) * msg.value;
        uint256 ethAmount = (10**18 * (10**18 * ethPrice)) / usdcAmount;

        require(
            tokensAmount * 10**18 == usdcAmount,
            "Put the appropriate amount of USDC for that amount of ETH."
        );

        require(
            msg.value == ethAmount,
            "Put the appropriate amount of ETH for that amount of USDC."
        );

        usdcContract.transferFrom(msg.sender, address(this), tokensAmount);

        ethPool += msg.value;
        tokenPool += tokensAmount;
    }

    function test() external {
        usdcContract.transferFrom(msg.sender, address(this), 100);
    }

    receive() external payable {}
}
