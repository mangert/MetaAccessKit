// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import { ETHAccountV2 } from "./ETHAccountV2.sol";
import { Clones } from "@openzeppelin/contracts/proxy/Clones.sol";
import { IDGenerator } from "../libs/IDGenerator.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title AccountBox  
 * @author mangert
 * @notice контракт-фабрика, реализует шаблон минимальных прокси для простых контрактов-счетов
 */
contract AccountBox is ReentrancyGuard {
    
    // solhint-disable immutable-vars-naming
    /// @notice ссылка на контракт-шаблон
    address public immutable implementation;
    // solhint-enable immutable-vars-naming 
    
    //хранилище созданных счетов
    mapping (address client => mapping (bytes4 id => address account)) private accounts;    
    /// @notice счетчики для адресов
    mapping(address => uint8) public userCounters;

    /**
     * @notice событие сообщает о создании нового счета
     * @param owner - адрес владелеца
     * @param id - идентификатор 
     * @param account - адрес созданного счета
     */
    event AccountCreated(address indexed owner, bytes4 indexed id, address indexed account);    
    
    /// @notice в конструкторе определяется адрес имплементации контракта-счета
    /// @param trustedForwarder адрес доверенного форвардера, которым будут пользоваться контраткты-счета    
    constructor(address trustedForwarder) {        
        implementation = address(new ETHAccountV2(trustedForwarder));
    }   
    
    //solhint-disable comprehensive-interface
    /**
     * @notice функция создает новый минимальный прокси для шаблонного контракта-счета
     * @return address созданный контракт минимального прокси
     */
    function createClone() external nonReentrant returns (address) {
        
        address payable clone = payable (Clones.clone(implementation)); //создаем клон

        //инициализируем и увеличиваем для пользователя счетчик
        // solhint-disable-next-line gas-increment-by-one
        ETHAccountV2(clone).initialize(userCounters[msg.sender]++, msg.sender); 
        
        bytes4 accountId = ETHAccountV2(clone).accountID(); //получаем ID
        accounts[msg.sender][accountId] = clone; //записываем в хранилище
        
        emit AccountCreated(msg.sender, accountId, clone);
        
        return clone;
    }

    /**
     * @notice функция возращает адрес прокси-аккаунта исходя из адреса владельца и его индекса создания
     * @param owner - адрес владельца для поиска
     * @param index - индекс (по порядку создания)
     * @return address прокси контракт по локальному индексу владельца
     */
    function getAccountByIndex(address owner, uint8 index) public view returns (address) {
        bytes4 id = IDGenerator.computeId(owner, index);
        return accounts[owner][id];
    }      
}

