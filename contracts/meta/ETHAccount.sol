// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import { IETHAccount } from "./IETHAccount.sol";

/**
 * @title ETHAccount
 * @notice 
 */

contract ETHAccount is IETHAccount {
    
    bytes4 public immutable accountID;
    address private owner;

    modifier onlyOwner() {
        require(msg.sender == owner, UnauthorizedAccount(msg.sender));
        _;
    }

    constructor(uint8 _id) {
        accountID = bytes4(keccak256(abi.encode(_id, msg.sender)));
        owner = msg.sender;
    }

    function deposit() external payable {
        emit Deposited(msg.sender, msg.value);
    }

    function withdraw(
        address payable recipient,
        uint256 amount
    ) external onlyOwner {
        _withdrawInternal(recipient, amount);        
    } 

    function _withdrawInternal(
        address payable recipient,
        uint256 amount
    ) internal {
        require(amount <= address(this).balance, InsufficientFunds(amount, address(this).balance));

        (bool success, ) = recipient.call{value: amount}("");
        require(success, WitdrawFailed(recipient, amount));

    emit Withdrawed(recipient, amount);
    }
}