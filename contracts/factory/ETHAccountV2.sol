// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import { IETHAccount } from "../commonInterfaces/IETHAccount.sol";
import { ERC2771Context } from "../meta/ERC2771Context.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { IDGenerator } from "../libs/IDGenerator.sol";

/**
 * @title ETHAccount
 * @author mangert
 * @notice версия контракта для использования через CloneFactory  
 */

contract ETHAccountV2 is IETHAccount, ERC2771Context, ReentrancyGuard {
    
    /// @notice идентификатор счета
    bytes4 public accountID; 
    address private owner; //владелец
    bool private _initialized; //флаг инициализации клона

    error ReInitializationdAccout();

    modifier onlyOwner() { //модификатор для контроля вывода
        require(_msgSender() == owner, UnauthorizedAccount(_msgSender()));
        _;
    }

    /// @notice в конструкторе определяется адрес доверенного форвардера
    /// @param trustedForwarder_ адрес доверенного форвардера
    constructor(address trustedForwarder_) ERC2771Context(trustedForwarder_){}

    //solhint-disable comprehensive-interface
    /// @notice на случай, если пользователь просто кинет деньги
    /// @notice без вызова функции - по сути, просто дублируем deposit
    receive() external payable { 
        emit Deposited(_msgSender(), msg.value);
    }

    /// @notice функция инициализации нужна, так как требуется устанавливать параметры
    /// после деплоя фабрикой
    /// @param _id - индекс, передается фабрикой при вызове
    /// @param _owner - владелец счета    
    function initialize(uint8 _id, address _owner) external {
        
        require(!_initialized, ReInitializationdAccout()); 
        _initialized = true;
        
        //формируем идентификатор исходя из переданного индекса и адреса владельца
        accountID = IDGenerator.computeId(_owner, _id); 
        owner = _owner; //назначаем владельца;
    }   
    //solhint-enable comprehensive-interface
   
    //реализация функций интерфейса IETHAccount
    /**
     * @notice функция принимает вклад на контракт
     */
    function deposit() external override payable { 
        emit Deposited(_msgSender(), msg.value);
    }

    /**
     * @notice функция вывода средств
     * проверка баланса вынесена в служебную функцию
     * @param recipient - адрес вывода
     * @param amount - сумма вывода
     */
    function withdraw( 
        address payable recipient,
        uint256 amount
    ) external override onlyOwner nonReentrant { //функция вывода
        _withdrawInternal(recipient, amount);        
    } 

    //служебные функции            
    
    /**
     * @notice служебная функция вывода средств
     * @param recipient - адрес вывода
     * @param amount - сумма вывода
     */
    function _withdrawInternal(
        address payable recipient,
        uint256 amount
    ) internal {
        require(recipient != address(0), ZeroAddressProvided());
        // solhint-disable-next-line gas-strict-inequalities
        require(amount <= address(this).balance, InsufficientFunds(amount, address(this).balance)); //проверяем баланс

        emit Withdrawed(recipient, amount);

        (bool success, ) = recipient.call{value: amount}("");
        require(success, WitdrawFailed(recipient, amount));     
    }
}