// SPDX-License-Identifier: no-license
pragma solidity 0.8.17;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract EthToUsdc is ERC20 {
    ERC20 usdcContract;
    uint256 ethPool;
    uint256 tokenPool;

    constructor(address _usdcContract) payable ERC20("EthToUsdc", "ETUC") {
        usdcContract = ERC20(_usdcContract);
    }

    function deposit(uint256 tokensAmount) external payable {
        require(
            usdcContract.balanceOf(msg.sender) >= tokensAmount,
            "Insufficient ERC20 funds."
        );

        usdcContract.transferFrom(msg.sender, address(this), tokensAmount);

        ethPool += msg.value;
        tokenPool += tokensAmount;
    }

    receive() external payable {}
}
