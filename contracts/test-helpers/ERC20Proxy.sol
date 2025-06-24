// SPDX-License-Identifier: MIT

pragma solidity ^0.8.29;

import "../erc20/AmetistToken.sol";

/**
 * @title ERC20Proxy
 * @notice вспомогательный контракт для тестирования функционала Permit в токене ERC20
 */
contract ERC20Proxy {
    
    function doSend (    
        address token,
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        AmetistToken(token).permit(owner, spender, value, deadline, v, r, s);
    }


    


}