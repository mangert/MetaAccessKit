// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import { IETHAccount } from "../commonInterfaces/IETHAccount.sol";
import { ERC2771Context } from "./ERC2771Context.sol";
import "../libs/IDGenerator.sol";

/**
 * @title ETHAccount2771
 * @notice пример контракта для демонстрации механизма метатранзакций с использованием
 * стандарта ERC2771
 */

contract ETHAccountV1 is IETHAccount, ERC2771Context {
    
    bytes4 public immutable accountID; // идентификатор 
    address private owner; //владелец

    modifier onlyOwner() { //модификатор для контроля вывода
        require(_msgSender() == owner, UnauthorizedAccount(_msgSender()));
        _;
    }

    constructor(uint8 _id, address trustedForwarder_) ERC2771Context (trustedForwarder_) {
              
        owner = msg.sender; //назначаем владельца
        accountID = IDGenerator.computeId(owner, _id); //формируем идентификатор исходя из переданного индекса и адреса владельца        
    }

    //реализация функций интерфейса IETHAccount
    /**
     * @notice функция принимает вклад на контракт
     */
    function deposit() external payable { 
        emit Deposited(_msgSender(), msg.value);
    }

    /**
     * @notice функция вывода средств
     * проверка баланса вынесена в служебную функцию
     * @param recipient - адрес вывода
     * @param amount - сумма вывода
     */
    function withdraw( 
        address payable recipient,
        uint256 amount
    ) external onlyOwner { //функция вывода
        _withdrawInternal(recipient, amount);        
    } 

    //служебные функции        

    //на случай, если пользователь просто кинет деньги
    //без вызова функции - по сути, просто дублируем deposit
    receive() external payable { 
        emit Deposited(_msgSender(), msg.value);
    }
    
    /**
     * @notice служебная функция вывода средств
     * @param recipient - адрес вывода
     * @param amount - сумма вывода
     */
    function _withdrawInternal(
        address payable recipient,
        uint256 amount
    ) internal {
        require(amount <= address(this).balance, InsufficientFunds(amount, address(this).balance)); //проверяем баланс

        (bool success, ) = recipient.call{value: amount}("");
        require(success, WitdrawFailed(recipient, amount)); 

    emit Withdrawed(recipient, amount);
    }
}