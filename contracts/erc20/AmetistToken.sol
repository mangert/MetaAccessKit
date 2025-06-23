// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.29;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol"; //импортируем основной функционал токена ЕRC20
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol"; //импортируем интерфейс метаданных
import "./ERC20Permit.sol";

contract AmetistToken is ERC20, ERC20Permit {    

    constructor()  ERC20("Ametist", "AME") ERC20Permit("Ametist")
    { }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}