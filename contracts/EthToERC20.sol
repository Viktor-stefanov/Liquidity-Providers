// SPDX-License-Identifier: no-license
pragma solidity 0.8.17;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "hardhat/console.sol";
import "./PriceFeed.sol";

contract EthToERC20 is ERC20 {
    PriceFeed priceFeed;
    mapping(address => ERC20) erc20Contracts;
    uint256 ethPool;
    uint256 tokenPool;

    constructor(address[] memory _erc20Contracts, address _priceFeed)
        payable
        ERC20("EthToUsdc", "ETUC")
    {
        for (uint256 i = 0; i < _erc20Contracts.length; i++) {
            address tokenContract = _erc20Contracts[i];
            erc20Contracts[tokenContract] = ERC20(tokenContract);
        }
        priceFeed = PriceFeed(_priceFeed);
    }

    function addToken(address _erc20Contract) external {
        require(
            address(erc20Contracts[_erc20Contract]) == address(0),
            "This token contract is already in the system."
        );

        erc20Contracts[_erc20Contract] = ERC20(_erc20Contract);
    }

    function deposit(address _erc20Contract, uint256 _tokensAmount)
        external
        payable
    {
        require(
            address(erc20Contracts[_erc20Contract]) != address(0),
            "There is no such token contract YET in our system."
        );

        ERC20 tokenContract = erc20Contracts[_erc20Contract];
        require(
            tokenContract.balanceOf(msg.sender) >= _tokensAmount,
            "Insufficient ERC20 funds."
        );

        console.log(address(tokenContract));
        uint256 usdcPrice = uint256(priceFeed.getPrice(address(tokenContract)));
        uint256 ethPrice = uint256(
            priceFeed.getPrice(0xf953b3A269d80e3eB0F2947630Da976B896A8C5b)
        );

        // target amount to deposit  usdc: ethPrice/usdcPrice * usdcIn
        uint256 targetTokenAmount = (ethPrice / usdcPrice) * msg.value;
        uint256 targetEthAmount = (10**18 * (10**18 * ethPrice)) /
            targetTokenAmount;

        require(
            _tokensAmount * 10**18 == targetTokenAmount,
            "Put the appropriate amount of USDC for that amount of ETH."
        );

        require(
            msg.value == targetEthAmount,
            "Put the appropriate amount of ETH for that amount of USDC."
        );

        tokenContract.transferFrom(msg.sender, address(this), _tokensAmount);

        ethPool += msg.value;
        tokenPool += _tokensAmount;
    }

    receive() external payable {}
}
