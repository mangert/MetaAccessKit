// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import { ETHAccountV2 } from "../factory/ETHAccountV2.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "../libs/IDGenerator.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/**
 * @title AccountBoxV1  
 * @notice Контракт-фабрика в обновляемой редакции (паттерн UUPSUpgradeable)
 * первая редакция реализации
 */
contract AccountBoxV1 is Initializable, UUPSUpgradeable, OwnableUpgradeable{
    
    address public implementation; //ссылка на контракт-шаблон
    
    //хранилище созданных счетов
    mapping (address client => mapping (bytes4 id => address account)) private accounts;    
    //счетчики для адресов
    mapping(address => uint8) public userCounters;

    /**
     * @notice событие сообщает о создании нового счета
     * @param owner - адрес владелеца
     * @param id - идентификатор 
     * @param account - адрес созданного счета
     */
    event AccountCreated(address indexed owner, bytes4 indexed id, address account);    
    
    /**
     * @notice - функция инициализации - вместо конструктора
     * @param trustedForwarder -
     * @param initialOwner -
     */
    function initialize(address trustedForwarder, address initialOwner) public initializer {
        implementation = address(new ETHAccountV2(trustedForwarder));
        __Ownable_init(initialOwner);
        __UUPSUpgradeable_init();
    }      
    
    /**
     * @notice функция создает новый минимальный прокси для шаблонного контракта-счета
     */
    function createClone() external returns (address) {
        
        address payable clone = payable (Clones.clone(implementation)); //создаем клон

        ETHAccountV2(clone).initialize(userCounters[msg.sender]++, msg.sender); //инициализируем и увеличиваем для пользователя счетчик
        
        bytes4 accountId = ETHAccountV2(clone).accountID(); //получаем ID
        accounts[msg.sender][accountId] = clone; //записываем в хранилище
        
        emit AccountCreated(msg.sender, accountId, clone);
        
        return clone;
    }

    /**
     * @notice функция возращает адрес прокси-аккаунта исходя из адреса владельца и его индекса создания
     * @param owner - адрес владельца для поиска
     * @param index - индекс (по порядку создания)
     */
    function getAccountByIndex(address owner, uint8 index) public view returns (address) {
        bytes4 id = IDGenerator.computeId(owner, index);
        return accounts[owner][id];
    }      

    /**
     * @notice функция проверяет права доступа в UUPS. Вызывается внутри _upgrade-функций
     * в текущей реализации вся логика вынесена в модификатор onlyOwner
     * @param newImplementation - ссылка на обновленную реализацию
     */
    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyOwner
    {}
}