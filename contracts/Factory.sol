// SPDX-License-Identifier: no-license
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Factory {
    mapping(address => ERC20) tokenToExchange;
    mapping(ERC20 => address) exchangeToToken;

    function deploy(address token) public {
        ERC20 con = ERC20(token);

    }
}
