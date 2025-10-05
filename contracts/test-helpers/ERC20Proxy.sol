// SPDX-License-Identifier: MIT

pragma solidity ^0.8.29;

import { AmetistToken } from "../erc20/AmetistToken.sol";

/**
 * @title ERC20Proxy
 * @author mangert
 * @notice вспомогательный контракт для тестирования функционала Permit в токене ERC20
 */
contract ERC20Proxy {

    //solhint-disable comprehensive-interface
    
    /**
     * @notice вызываем функцию permit на токене от имени контракта
     * @param token адрес токена
     * @param owner владелец
     * @param spender адрес, на кого выписываем permit
     * @param value сумма
     * @param deadline срок действия сообщения
     * @param v компонент подписи
     * @param r компонент подписи
     * @param s компонент подписи
     */
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