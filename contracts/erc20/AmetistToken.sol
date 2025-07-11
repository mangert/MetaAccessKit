// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.29;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol"; //импортируем основной функционал токена ЕRC20
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol"; //импортируем интерфейс метаданных

import "./ERC20Permit.sol";
import "./AccessControl.sol";

contract AmetistToken is ERC20, ERC20Permit, AccessControl {    

    bytes32 public constant MINTER_ROLE = keccak256(bytes("MINTER_ROLE")); //создаем роль "минтера"

    constructor()  ERC20("Ametist", "AME") ERC20Permit("Ametist")
    { 
        //делаем начальные установки ролей
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender); //выдаем деплоеру "админа по умолчанию"
        _grantRole(MINTER_ROLE, msg.sender); //выдаем деплоеру роль "минтера"
        _setRoleAdmin(MINTER_ROLE, DEFAULT_ADMIN_ROLE); //назначаем "админа по умолчанием" админом роли "минтер"
    }

    //функцию может вызывать только адрес с соответстующей ролью
    function mint(address to, uint256 amount) onlyRole(MINTER_ROLE) external {
        _mint(to, amount);
    }
}