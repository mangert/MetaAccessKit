// SPDX-License-Identifier: MIT

pragma solidity ^0.8.29;

import { ERC2771Context } from "./ERC2771Context.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { EIP712 } from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import { Nonces } from "@openzeppelin/contracts/utils/Nonces.sol";
import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import { Errors } from "@openzeppelin/contracts/utils/Errors.sol";

/**
 * @title ERC2771Forwarder 
 * @notice отдельный "форвардер"
 * из библиотетки openzeppelin, включен для использования в ETHAccount2771
 * @author @openzeppelin
 */
contract ERC2771Forwarder is EIP712, Nonces {
    using ECDSA for bytes32; //псевдоним типа для удобства

    
    /// @notice Структура EIP-2771 для описания мета-транзакции.
    /// @dev Порядок полей и их типы строго соответствуют стандарту.
    /// Несмотря на предупреждения линтера (упаковка в storage не оптимальна),
    /// поля не могут быть переставлены без нарушения совместимости
    /// с EIP-712 / forwarder-подписью.    
    // solhint-disable gas-struct-packing
    struct ForwardRequestData {
        address from; //"настоящий" пользователь, который подписал вызов
        address to;  //адрес "целевого" контракта
        uint256 value; //передаваемые в транзакции деньги
        uint256 gas;
        uint48 deadline;
        bytes data; //селектор вызываемой функции с аргументами
        bytes signature; //подпись
    }
    // solhint-enable gas-struct-packing

    //константа  для описания формы сообщения, которое пользователь должен подписать при вызове    
    bytes32 internal constant _FORWARD_REQUEST_TYPEHASH =
        // solhint-disable-next-line gas-small-strings
        keccak256(
            "ForwardRequest(address from,address to,uint256 value,uint256 gas,uint256 nonce,uint48 deadline,bytes data)"
        );

    //solhint-disable gas-indexed-events
    /**
     * @notice порождается в случае исполнения запроса на выполнение функции
     * @param signer - пользователь, подписавший сообщение
     * @param nonce - текущее значение счетчика сообщений пользователя
     * @param  success - результат вызова
     */
    event ExecutedForwardRequest(address indexed signer, uint256 nonce, bool success);
    //solhint-enable gas-indexed-events

    /**
     * @notice ошибка индицирует неверного подписанта
     * @param signer - подисант, выведенный из расшифровки запроса
     * @param from - отправитель запроса
     */
    error ERC2771ForwarderInvalidSigner(address signer, address from);

    /**
     * @notice ошибка индицирует некорректную сумму в запросе
     * @param requestedValue - сумма транзакции, записанная в запросе
     * @param msgValue - сумма, полученная в транзакции от релеера
     */
    error ERC2771ForwarderMismatchedValue(uint256 requestedValue, uint256 msgValue);

    /**
     * @notice ошибка индицирует истекший срок действия подписаннного сообщения
     * @param deadline - срок действия сообщения     
     */
    error ERC2771ForwarderExpiredRequest(uint48 deadline);

    /**
     * @notice ошибка индицирует, что целевой контракт не поддерживает этот контракт как форвардер
     * @param target - адрес целевого контракта
     * @param forwarder - поддерживаемый форвардер
     */
    error ERC2771UntrustfulTarget(address target, address forwarder);

    
    /// @notice конструктор устанавливает параметры форвардера
    /// @param name имя нашего форвардера
    constructor(string memory name) EIP712(name, "1") {}    

    //solhint-disable comprehensive-interface
    /**
     * @notice функция выполняет запрос на целевом контракте
     * @param request - сообщение-запрос
     */
    function execute(ForwardRequestData calldata request) public payable virtual {
        
        if (msg.value != request.value) { //проверяем сумму
            revert ERC2771ForwarderMismatchedValue(request.value, msg.value);
        }

        if (!_execute(request, true)) { //запускаем внутреннюю функцию выполнения (остальные проверки там)
            revert Errors.FailedCall(); //если неуспешно - кидаем ошибку вызова
        }
    }
    
    /**
     * @notice функция выполняет "пачку" запросов
     * @param requests - массив запросов
     * @param refundReceiver - адрес, куда вернуть средства, если один из запросов из пачки отвалится
     */
    function executeBatch(
        ForwardRequestData[] calldata requests,
        address payable refundReceiver
    ) public payable virtual {
        //если задан нулевой адрес возврата, то будем запускать execute с true
        bool atomic = refundReceiver == address(0); 
        
        // slither-disable-next-line uninitialized-local-variables
        uint256 requestsValue;
        // slither-disable-next-line uninitialized-local-variables
        uint256 refundValue;

        //цикл выполнения
        for (uint256 i; i < requests.length; ++i) {
            requestsValue += requests[i].value;
            bool success = _execute(requests[i], atomic);
            if (!success) {
                refundValue += requests[i].value;
            }
        }
        
        if (requestsValue != msg.value) { //проверяем достаточность суммы
            revert ERC2771ForwarderMismatchedValue(requestsValue, msg.value);
        }

        //если какие-то запросы отвалились, вернем сумму, предназначенную для их выполнения
        if (refundValue != 0) {
        
            Address.sendValue(refundReceiver, refundValue);
        }
    }
    
    /**
     * @notice функция возращает результат проверки форвардера целевого контаркта, подписанта и дедлайна 
     * @param request - сообщение-запрос на вызов функции
     * @return bool результат проверки запроса
     */
    function verify(ForwardRequestData calldata request) public view virtual returns (bool) {
        (bool isTrustedForwarder, bool active, bool signerMatch, ) = _validate(request);
        return isTrustedForwarder && active && signerMatch;
    }
    
    /**
     * @notice внутренняя функция, выполняющая запрос
     * @param request - сообщение-запрос
     * @param requireValidRequest - признак указывает, как организовать проверки запроса
     *  - ревертить при ошибках или просто не выполнять запрос
     * @return success результат выполнения запроса
     */
    function _execute(
        ForwardRequestData calldata request,
        bool requireValidRequest
    ) internal virtual returns (bool success) {
        (bool isTrustedForwarder, bool active, bool signerMatch, address signer) = _validate(request);

        
        if (requireValidRequest) { //делаем проверки, если в параметрах передано true, и, если не прошло, сразу ревертим
            if (!isTrustedForwarder) {
                revert ERC2771UntrustfulTarget(request.to, address(this)); //проверяем форвардера в целевом контракте
            }

            if (!active) {
                revert ERC2771ForwarderExpiredRequest(request.deadline); //проверяем дедлайн 
            }

            if (!signerMatch) {
                revert ERC2771ForwarderInvalidSigner(signer, request.from); //проверяем подписанта
            }
        }
        
        //если форвардер поддерживается, подпись валидна и дедлайн не прошел
        if (isTrustedForwarder && signerMatch && active) { 
            // будем выполнять запрос
            uint256 currentNonce = _useNonce(signer); //берем nonce

            uint256 reqGas = request.gas;
            address to = request.to;
            uint256 value = request.value;
            bytes memory data = abi.encodePacked(request.data, request.from);

            uint256 gasLeft;
            //низкоуровневый вызов функции целевого контракта
            // solhint-disable no-inline-assembly
            assembly ("memory-safe") {
                success := call(reqGas, to, value, add(data, 0x20), mload(data), 0, 0)
                gasLeft := gas()
            }
            // solhint-enable no-inline-assembly

            _checkForwardedGas(gasLeft, request); //проверяем оставшийся газ

            //эмитируем событие, что запрос выполнен успешно или нет
            emit ExecutedForwardRequest(signer, currentNonce, success); 
        }
    }

    //solhint-enable comprehensive-interface

    /**
     * @notice служебная функция проверяет параметры запроса - указан ли 
     * в целевом контракте этот контракт как доверенный форвардер,
     * не истек ли дедлайн, действительна ли подпись и возвращает соответстующие значения и подписанта
     * @param request - запрос
     * @return isTrustedForwarder - форвардер зарегистрирован в целевом контракте
     * @return active - дедлайн не истек
     * @return signerMatch - подпись совпала 
     * @return signer - подписант
     */
    function _validate(
        ForwardRequestData calldata request
    ) internal view virtual returns (bool isTrustedForwarder, bool active, bool signerMatch, address signer) {
        (bool isValid, address recovered) = _recoverForwardRequestSigner(request);

        return (
            _isTrustedByTarget(request.to),
            //solhint-disable not-rely-on-time
            //solhint-disable gas-strict-inequalities            
            // slither-disable-next-line timestamp
            request.deadline >= block.timestamp,
            isValid && recovered == request.from,
            recovered
            //solhint-enable gas-strict-inequalities            
            //solhint-enable not-rely-on-time            
        );
    }

    /**
     * @notice служебная функция - возращает из сообщения подписанта и проверяет валидность подписи
     * @param request - сообщение-запрос на выполнение функций
     * @return isValid результат проверки на валидность
     * @return signer адрес, подписавший сообщение
     */
    function _recoverForwardRequestSigner(
        ForwardRequestData calldata request
    ) internal view virtual returns (bool isValid, address signer) {
        (address recovered, ECDSA.RecoverError err, ) = _hashTypedDataV4(
            keccak256(
                abi.encode(
                    _FORWARD_REQUEST_TYPEHASH,
                    request.from,
                    request.to,
                    request.value,
                    request.gas,
                    nonces(request.from),
                    request.deadline,
                    keccak256(request.data)
                )
            )
        ).tryRecover(request.signature);

        return (err == ECDSA.RecoverError.NoError, recovered);
    }

    /**
     * @notice служебная функция проверяет, является ли наш форвардер доверенным на целевом контракте
     * @param target - адрес целевого контаркта
     * @return bool, является ли этот контракт доверенным форвардером в целевом
     */
    function _isTrustedByTarget(address target) internal view virtual returns (bool) {
        bytes memory encodedParams = abi.encodeCall(ERC2771Context.isTrustedForwarder, (address(this)));

        bool success;
        uint256 returnSize;
        uint256 returnValue;
        // solhint-disable no-inline-assembly
        assembly ("memory-safe") { //делаем низкоуровневый вызов функции isTrustedForwarder на целевом контракте
            success := staticcall(gas(), target, add(encodedParams, 0x20), mload(encodedParams), 0, 0x20)
            returnSize := returndatasize()
            returnValue := mload(0)
        }
        // solhint-enable no-inline-assembly
        // solhint-disable-next-line gas-strict-inequalities
        return success && returnSize >= 0x20 && returnValue > 0;
    }

    /**
     * @notice служебная функция проверяет хватило ли газа для выполнения запроса
     * защита от злонамеренных действий или ошибок релеера при передаче запроса
     * то есть функция нужна чтобы проверить, что relayer передал достаточно газа и вызов не “задушился” искусственно.
     * @param gasLeft - остаток газа после вызова
     * @param request - сам запрос
     */
    function _checkForwardedGas(uint256 gasLeft, ForwardRequestData calldata request) private pure {
        
        //проверяем, что оставшийся после вызова газ меньше, чем EVM оставляет себе по правилу 63/64
        if (gasLeft < request.gas / 63) {
            // solhint-disable no-inline-assembly
            assembly ("memory-safe") { //и если меньше, ревертим транзакцию
                invalid() //гарантированно откатывает транзакцию и сжигает весь газ
            }
            // solhint-enable no-inline-assembly
        }
    }
}