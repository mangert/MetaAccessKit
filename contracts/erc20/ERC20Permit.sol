// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {IERC20Permit} from "./IERC20Permit.sol";

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { EIP712 } from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import { Nonces } from "@openzeppelin/contracts/utils/Nonces.sol";

/// @notice абстрактный контракт содержит функционал permit для токена ERC20
/// @title ERC20Permit
/// @author mangert
abstract contract ERC20Permit is ERC20, IERC20Permit, EIP712, Nonces{
    
    //константа  для описания формы сообщения, которое пользователь должен подписать при вызове
    // solhint-disable-next-line gas-small-strings
    bytes32 private constant PERMIT_TYPEHASH = keccak256
        ("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

    //описания кастомных ошибок
    /**
     * @notice ошибка индицирует истечение дедлайна
     * @param deadline - срок дедлайна
     */
    error ERC2612ExpiredSignature(uint256 deadline);

    /**
     * @notice ошибка индицирует неверную подпись
     * @param signer - подписант
     * @param owner - владелец
     */
    error ERC2612InvalidSigner(address signer, address owner);    
    
    /// @notice конструктор определяет константы пермит
    /// @param name задает имя токена
    constructor(string memory name) EIP712(name, "1") {}

    //реализация функции интерфейса IERC20Permit
    
    /// @notice функция создает permit-approve
    /// @param owner владелец
    /// @param spender адрес, на который аппрувим
    /// @param value сумма
    /// @param deadline срок действия разрешения
    /// @param v компонент подписи
    /// @param r компонент подписи
    /// @param s компонент подписи
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external virtual {
        // solhint-disable not-rely-on-time
        // solhint-disable-next-line gas-strict-inequalities
        require(block.timestamp <= deadline, ERC2612ExpiredSignature(deadline)); //сначала проверяем дедлайн
        
        bytes32 structHash = keccak256( //формируем message
            abi.encode(
                PERMIT_TYPEHASH, //стандартная константа
                owner,
                spender,
                value,
                _useNonce(owner), //функция определена в Nonces.sol
                deadline
            )
        );
        // solhint-enable not-rely-on-time

        bytes32 hash = _hashTypedDataV4(structHash); //формируем digest (полная хэш-структура по EIP-712):

        address signer = ECDSA.recover(hash, v, r, s); //восстанавливаем подписанта

        require(signer == owner, ERC2612InvalidSigner(signer, owner)); //и проверяем, что подписал владелец
        
        _approve(owner, spender, value); //даем разрешение на использование токенов
            
    }

    // solhint-disable func-name-mixedcase
    /**
     * @notice Реализация стандартной функции для интерфейса IERC20Permit
     * @return bytes32 домен для шифрования      
     */
    function DOMAIN_SEPARATOR() external view returns (bytes32) {
        return _domainSeparatorV4(); //обращаемся к стандартной функции
    }
    // solhint-enable func-name-mixedcase               

    /**
     * @notice Реализация публичной функции для интерфейса IERC20Permit
     * @notice Функция проксирует вызов к Nonces, где всё хранится и обновляется.
     * @param owner - адрес владельца, для которого считаем нонсы
     * @return uint256 нонс владельца
     */
    function nonces(address owner) public view virtual override(IERC20Permit, Nonces) returns (uint256) {
        return super.nonces(owner);
    }   
    
}