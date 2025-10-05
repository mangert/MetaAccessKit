// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

/**
 * @title IDGenerator 
 * @author mangert
 * @notice сделано для унификации метода расчета идентификатора счета при создании счета и в контракте-фабрике
 */
library IDGenerator {
    
    /**
     * @notice возвращает расчетное значение идентификатора
     * @param owner - адрес владельца счета
     * @param index - индекс
     * @return bytes4 расчетный ID 
     */
    function computeId(address owner, uint8 index) internal pure returns (bytes4) {
        return bytes4(keccak256(abi.encode(index, owner)));
    }
}
