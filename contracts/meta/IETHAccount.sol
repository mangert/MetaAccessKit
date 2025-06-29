// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

/**
 * @title IETHAccount
 * @notice интерфейс простого контракта-счета для демонстрации метатранзакций
 */

interface IETHAccount {

    event Deposited(address indexed depositor, uint256 amount);
    event Withdrawed(address indexed withdrawer, address indexed recipient, uint256 amount);
    
    error InsufficientFunds(uint256 withdrawAmount, uint256 balance);    
    error UnauthorizedAccount(address sender);    
    error WitdrawFailed(address recipient, uint256 amount);

    
    function deposit() external payable;

    function withdraw(address payable recipient, uint256 amount) external;

}