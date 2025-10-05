// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

/**
 * @title IETHAccount
 * @notice интерфейс простого контракта-счета для демонстрации мета-транзаций и фабрики контрактов
 * @author mangert
 */

interface IETHAccount {

    // solhint-disable gas-indexed-events    
    /// @notice событие сообщает о поступлении средств
    /// @param depositor - адрес, с которого поступили средства
    /// @param amount - сумма поступления        
    event Deposited(address indexed depositor, uint256 amount); 
    
    /**
     * @notice событие сообщает об успешном выводе     * 
     * @param recipient - адрес вывода
     * @param amount - сумма вывода
     */    
    event Withdrawed(address indexed recipient, uint256 amount);

    // solhint-enable gas-indexed-events
    
    /**
     * @notice ошибка индицирует нехватку средств на балансе для вывода
     */
    error InsufficientFunds(uint256 withdrawAmount, uint256 balance);    
    /**
     * @notice ошибка индицирует попытку неавторизованного вывода
     */
    error UnauthorizedAccount(address sender);
    /**
     * @notice ошибка индицирует неудачную операцию вывода
     */
    error WitdrawFailed(address recipient, uint256 amount);
    /**
    * @notice ошибка попытку вывода на нулевой адрес
    */
    error ZeroAddressProvided();


    /**
     * @notice функция принимает вклад на контракт
     */
    function deposit() external payable;

    /**
     * @notice функция вывода средств
     * @param recipient - адрес вывода
     * @param amount - сумма вывода
     */
    function withdraw(address payable recipient, uint256 amount) external;

}