// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.29;

//импортируем основной функционал токена ЕRC20
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol"; 

import { ERC20Permit } from "./ERC20Permit.sol";
import { AccessControl } from "./AccessControl.sol";

/**
 * @title AmetistToken 
 * @author mangert
 * @notice контракт ERC20, реализующий механизм ERC20Permit
 */
contract AmetistToken is ERC20, ERC20Permit, AccessControl {    

    /// @notice создаем роль минтера
    bytes32 public constant MINTER_ROLE = keccak256(bytes("MINTER_ROLE"));

    /// @notice в конструкторе выдаются роли "по умолчанию" на деплоера
    constructor()  ERC20("Ametist", "AME") ERC20Permit("Ametist")
    { 
        //делаем начальные установки ролей
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender); //выдаем деплоеру "админа по умолчанию"
        _grantRole(MINTER_ROLE, msg.sender); //выдаем деплоеру роль "минтера"
        _setRoleAdmin(MINTER_ROLE, DEFAULT_ADMIN_ROLE); //назначаем "админа по умолчанием" админом роли "минтер"
    }


    //solhint-disable comprehensive-interface
    /**
     * @notice функция позволяет минтить токены
     * @notice функцию может вызывать только адрес с соответстующей ролью
     * @param to адрес куда будем минтить токены
     * @param amount количество минтящихся токенов
     */
    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }
}