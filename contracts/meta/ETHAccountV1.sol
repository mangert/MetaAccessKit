// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import { IETHAccount } from "../commonInterfaces/IETHAccount.sol";
import { ERC2771Context } from "./ERC2771Context.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { IDGenerator } from "../libs/IDGenerator.sol";

/**
 * @title ETHAccount2771
 * @notice пример контракта для демонстрации механизма метатранзакций с использованием 
 * стандарта ERC2771
 * @author mangert
 */

contract ETHAccountV1 is IETHAccount, ERC2771Context, ReentrancyGuard {
    
    // solhint-disable immutable-vars-naming
    ///@notice уникальный идентификатор счета    
    bytes4 public immutable accountID; 
    // solhint-enable immutable-vars-naming
    
    address private owner; //владелец

    modifier onlyOwner() { //модификатор для контроля вывода
        require(_msgSender() == owner, UnauthorizedAccount(_msgSender()));
        _;
    }

    /// @notice конструктор устанавливает владельца, доверенного форвардера и рассчитывает id счета
    /// @param _id индекс, на основании которого будет формироваться уникальный ID
    /// @param trustedForwarder_ адрес доверенного форвардера
    constructor(uint8 _id, address trustedForwarder_) ERC2771Context (trustedForwarder_) {
              
        owner = msg.sender; //назначаем владельца
        //формируем идентификатор исходя из переданного индекса и адреса владельца        
        accountID = IDGenerator.computeId(owner, _id); 
    }

    //solhint-disable comprehensive-interface
    /// @notice на случай, если пользователь просто кинет деньги
    /// без вызова функции - по сути, просто дублируем deposit
    receive() external payable { 
        emit Deposited(_msgSender(), msg.value);
    }
    //solhint-enable comprehensive-interface

    //реализация функций интерфейса IETHAccount
    /**
     * @notice функция принимает вклад на контракт
     */
    function deposit() external override payable { 
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
    ) external override nonReentrant onlyOwner { //функция вывода
        _withdrawInternal(recipient, amount);        
    } 

    //служебные функции            
    
    /**
     * @notice служебная функция вывода средств
     * @param recipient - адрес вывода
     * @param amount - сумма вывода
     */
    function _withdrawInternal(
        address payable recipient,
        uint256 amount
    ) internal {
        require(recipient != address(0), ZeroAddressProvided());
        // solhint-disable-next-line gas-strict-inequalities
        require(amount <= address(this).balance, InsufficientFunds(amount, address(this).balance)); //проверяем баланс

        emit Withdrawed(recipient, amount);

        (bool success, ) = recipient.call{value: amount}("");
        require(success, WitdrawFailed(recipient, amount));     
    }
}