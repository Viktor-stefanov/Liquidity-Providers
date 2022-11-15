// SPDX-License-Identifier: no-license
pragma solidity 0.8.17;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract UsdtContract is ERC20 {
    constructor(address _to) ERC20("UsdtMockCoin", "UTMC") {
        _mint(_to, 200000 ether);
    }
}
