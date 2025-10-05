// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import { ETHAccountV2 } from "../factory/ETHAccountV2.sol";
import { Clones } from "@openzeppelin/contracts/proxy/Clones.sol";
import { IDGenerator } from "../libs/IDGenerator.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

/**
 * @title AccountBoxV2 
 * @author mangert
 * @notice Контракт-фабрика в обновляемой редакции (паттерн UUPSUpgradeable)
 * вторая редакция реализации - добавлен общий счетчик созданных аккаунтов и функция-геттер
 */
contract AccountBoxV2 is 
    Initializable, 
    UUPSUpgradeable, 
    OwnableUpgradeable, 
    ReentrancyGuardUpgradeable {
    ///@notice ссылка на контракт-шаблон
    address public implementation;
    
    //хранилище созданных счетов
    mapping (address client => mapping (bytes4 id => address account)) private accounts;    
    ///@notice счетчики для адресов
    mapping(address => uint8) public userCounters;    

    /**
     * @notice событие сообщает о создании нового счета
     * @param owner - адрес владелеца
     * @param id - идентификатор 
     * @param account - адрес созданного счета
     */
    event AccountCreated(address indexed owner, bytes4 indexed id, address indexed account);       

    /// @custom:oz-upgrades-unsafe-allow constructor
    /// @notice Блокирующий конструктор для предоствращения вызова функции инициализации напрямую из имплементации
    constructor() {
        _disableInitializers();
    }
    //solhint-disable comprehensive-interface
    // solhint-disable ordering
    /**
     * @notice - функция инициализации - вместо конструктора
     * @dev Оставлена вверху контракта для лучшей читаемости,
     * несмотря на предупреждение линтера об "ordering".
     * @param trustedForwarder - адрес доверенного форвардера
     * @param initialOwner - адрес владельца
     */
    function initialize(address trustedForwarder, address initialOwner) public initializer {
        implementation = address(new ETHAccountV2(trustedForwarder));
        __Ownable_init(initialOwner);
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();
    }      
    
    /**
     * @notice функция создает новый минимальный прокси для шаблонного контракта-счета
     * @return address возвращает адрес созданного прокси-контракта
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
    // solhint-enable ordering

    /**
     * @notice функция возращает адрес прокси-аккаунта исходя из адреса владельца и его индекса создания
     * @param owner - адрес владельца для поиска
     * @param index - индекс (по порядку создания)
     * @return address возращает адрес прокси-аккаунта по локальному индексу владельца
     */
    function getAccountByIndex(address owner, uint8 index) public view returns (address) {
        bytes4 id = IDGenerator.computeId(owner, index);
        return accounts[owner][id];
    }      

    /**
     * @notice функция возращает адрес прокси-аккаунта исходя из адреса владельца и его id
     * добавлена во второй реализации для демонстрации "обновляемости"
     * @param owner - адрес владельца для поиска
     * @param _id - индекс (по порядку создания)
     * @return address адрес  прокси-аккуанта по локальному id владельца
     */
    function getAccountById(address owner, bytes4 _id) public view returns (address) {
        
        return accounts[owner][_id];
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
        // solhint-disable-next-line no-empty-blocks
    {}
}