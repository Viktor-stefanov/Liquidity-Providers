// SPDX-License-Identifier: no-license
pragma solidity 0.8.17;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract UsdcContract is ERC20 {
    constructor(address _to) ERC20("UsdcMockCoin", "UMC") {
        _mint(_to, 100000 ether);
    }
}
