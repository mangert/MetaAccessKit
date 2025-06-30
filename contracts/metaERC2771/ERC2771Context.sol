// SPDX-License-Identifier: MIT

pragma solidity ^0.8.29;

import { Context } from "@openzeppelin/contracts/utils/Context.sol";

/**
 * 
 */
abstract contract ERC2771Context is Context {    
    
    address private immutable _trustedForwarder; //ссылка на контракт-форвардер
    
    constructor(address trustedForwarder_) {
        _trustedForwarder = trustedForwarder_;
    }

    /**
     * @notice функция возвращает адрес контракта-форвардера
     */
    function trustedForwarder() public view virtual returns (address) {
        return _trustedForwarder;
    }

    /**
     * @notice Функция проверяет, является ли контракт зарегистрированным форвардером
     * @param адрес контракта для проверки
     */
    function isTrustedForwarder(address forwarder) public view virtual returns (bool) {
        return forwarder == trustedForwarder();
    }

    /**
     * @notice функция вытаскивает отправителя транзакции (перегрузка из Context)
     * если длина сообщения меньше длины адреса, или сообщение пришло не от зарегистрированного форвардера,
     * возвращается оригинальный msg.sender
     */
    function _msgSender() internal view virtual override returns (address) {
        uint256 calldataLength = msg.data.length;
        uint256 contextSuffixLength = _contextSuffixLength();
        if (isTrustedForwarder(msg.sender) && calldataLength >= contextSuffixLength) { //если вызов пришел от forwarder
            return address(bytes20(msg.data[calldataLength - contextSuffixLength:])); //берем "хвост" от данных
        } else {
            return super._msgSender(); //в противном случае обращаемся выше по иерархии - берем просто msg.sender
        }
    }

    /**
     * @notice функция вытаскивает соодержание сообщения (перегрузка из Context)
     * если длина сообщения больше длины адреса и сообщение пришло от зарегистрированного форвардера,
     * отрезается "хвост" - 20 байт адреса отправителя транзакции, в противном случае возвращается сообщение целиком
     */
    function _msgData() internal view virtual override returns (bytes calldata) {
        uint256 calldataLength = msg.data.length;
        uint256 contextSuffixLength = _contextSuffixLength();
        if (isTrustedForwarder(msg.sender) && calldataLength >= contextSuffixLength) {
            return msg.data[:calldataLength - contextSuffixLength]; //берем данные без "Хвоста" - отрезаем msg.sender
        } else {
            return super._msgData();
        }
    }

    /**
     * @notice функция возвращает длину адреса отправителя (перегрузка из Context)
     */
    function _contextSuffixLength() internal view virtual override returns (uint256) {
        return 20;
    }
}