// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import { IETHAccount } from "../meta/IETHAccount.sol";
import { ERC2771Context } from "./ERC2771Context.sol";

/**
 * @title ETHAccount
 * @notice 
 */

contract ETHAccount2771 is IETHAccount, ERC2771Context {
    
    bytes4 public immutable accountID;
    address private owner;

    modifier onlyOwner() {
        require(_msgSender() == owner, UnauthorizedAccount(_msgSender()));
        _;
    }

    constructor(uint8 _id, address trustedForwarder_) ERC2771Context (trustedForwarder_) {
        accountID = bytes4(keccak256(abi.encode(_id, msg.sender)));
        owner = msg.sender;
    }

    function deposit() external payable {
        emit Deposited(_msgSender(), msg.value);
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

    emit Withdrawed(owner, recipient, amount);
    }
}