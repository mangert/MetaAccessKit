// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

/**
 * @title IERC20Permit  
 * @notice Интерфейс расширения Permit для токенов стандарта ERC20 * 
 */

interface IERC20Permit {
    
    /**
     * @notice функция выдачи разрешения на расходование токенов
     * @param owner - адрес владельца
     * @param spender - адрес, на который выдается разрешение тратить токены
     * @param value  - сумма, на которую выдается разрешение
     * @param deadline - срок годности подписанного сообщения
     * @param v - компонент подписи
     * @param r - компонент подписи
     * @param s - компонент подписи
     */
    function permit(
        address owner, 
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    /**
     * @notice функция возращает текущий nonce по транзакциям выдачи разрешений на адрес владельца
     * @param owner - адрес владельца
     */
    function nonces(address owner) external view returns (uint256);
    
    /**
     * @notice функция возращает уникальный идентификатор “домена” подписей в контракте
     */   
    function DOMAIN_SEPARATOR() external view returns (bytes32);
    
}