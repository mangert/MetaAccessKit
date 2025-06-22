// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

/**
 * @title IERC20Permit  
 * @notice Интерфейс расширения Permit для токенов стандарта ERC20 * 
 */

interface IERC20Permit {
    
    /**
     * 
     * @param owner -
     * @param spender - 
     * @param value  -
     * @param deadline - 
     * @param v -  
     * @param r - 
     * @param s - 
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

    function nonces(address owner) external view returns (uint256);
    
    function DOMAIN_SEPARATOR() external view returns (bytes32);
    
}