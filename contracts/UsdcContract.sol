// SPDX-License-Identifier: no-license
pragma solidity 0.8.17;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract UsdcContract is ERC20 {
    constructor(address[] memory _to) ERC20("UsdcMockCoin", "UCMC") {
        for (uint128 i = 0; i < _to.length; i++) _mint(_to[i], 100000 ether);
    }
}
