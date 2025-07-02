// SPDX-License-Identifier: MIT

pragma solidity ^0.8.29;

import { ERC2771Context } from "./ERC2771Context.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { EIP712 } from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import { Nonces } from "@openzeppelin/contracts/utils/Nonces.sol";
import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import { Errors } from "@openzeppelin/contracts/utils/Errors.sol";

/**
 * @notice отдельный "форвардер"
 * из библиотетки openzeppelin, включен для использования в ETHAccount2771
 */
contract ERC2771Forwarder is EIP712, Nonces {
    using ECDSA for bytes32; //псевдоним типа для удобства

    //структура для сообщения-запроса на выполнение
    struct ForwardRequestData {
        address from; //"настоящий" пользователь, который подписал вызов
        address to;  //адрес "целевого" контракта
        uint256 value; //передаваемые в транзакции деньги
        uint256 gas;
        uint48 deadline;
        bytes data; //селектор вызываемой функции с аргументами
        bytes signature; //подпись
    }

    //константа  для описания формы сообщения, которое пользователь должен подписать при вызове
    bytes32 internal constant _FORWARD_REQUEST_TYPEHASH =
        keccak256(
            "ForwardRequest(address from,address to,uint256 value,uint256 gas,uint256 nonce,uint48 deadline,bytes data)"
        );

    /**
     * @notice порождается в случае исполнения запроса на выполнение функции
     * @param signer - пользователь, подписавший сообщение
     * @param nonce - текущее значение счетчика сообщений пользователя
     * @param  success - результат вызова
     */
    event ExecutedForwardRequest(address indexed signer, uint256 nonce, bool success);

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

    
    constructor(string memory name) EIP712(name, "1") {}    

    /**
     * @notice функция возращает результат проверки форвардера целевого контаркта, подписанта и дедлайна 
     * @param request - сообщение-запрос на вызов функции
     */
    function verify(ForwardRequestData calldata request) public view virtual returns (bool) {
        (bool isTrustedForwarder, bool active, bool signerMatch, ) = _validate(request);
        return isTrustedForwarder && active && signerMatch;
    }

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
        bool atomic = refundReceiver == address(0); //если задан нулевой адрес возврата, то будем запускать execute с true

        uint256 requestsValue;
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
     * @dev Validates if the provided request can be executed at current block timestamp with
     * the given `request.signature` on behalf of `request.signer`.
     */

    /**
     * @notice служебная функция проверяет параметры запроса - указан ли в целевом контракте этот контракт как доверенный форвардер,
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
            request.deadline >= block.timestamp,
            isValid && recovered == request.from,
            recovered
        );
    }

    /**
     * @notice служебная функция - возращает из сообщения подписанта и проверяет валидность подписи
     * @param request - сообщение-запрос на выполнение функций     
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
     * @dev Validates and executes a signed request returning the request call `success` value.
     *
     * Internal function without msg.value validation.
     *
     * Requirements:
     *
     * - The caller must have provided enough gas to forward with the call.
     * - The request must be valid (see {verify}) if the `requireValidRequest` is true.
     *
     * Emits an {ExecutedForwardRequest} event.
     *
     * IMPORTANT: Using this function doesn't check that all the `msg.value` was sent, potentially
     * leaving value stuck in the contract.
     */
    
    /**
     * @notice внутренняя функция, выполняющая запрос
     * @param request - сообщение-запрос
     * @param requireValidRequest - признак указывает, как организовать проверки запроса - ревертить при ошибках или просто не выполнять запрос
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
        
        if (isTrustedForwarder && signerMatch && active) { //если форвардер поддерживается, подпись валидна и дедлайн не прошел
            // будем выполнять запрос
            uint256 currentNonce = _useNonce(signer); //берем nonce

            uint256 reqGas = request.gas;
            address to = request.to;
            uint256 value = request.value;
            bytes memory data = abi.encodePacked(request.data, request.from);

            uint256 gasLeft;
            //низкоуровневый вызов функции целевого контракта
            assembly ("memory-safe") {
                success := call(reqGas, to, value, add(data, 0x20), mload(data), 0, 0)
                gasLeft := gas()
            }

            _checkForwardedGas(gasLeft, request); //проверяем оставшийся газ

            emit ExecutedForwardRequest(signer, currentNonce, success); //эмитируем событие, что запрос выполнен успешно или нет
        }
    }

    /**
     * @notice служебная функция проверяет, является ли наш форвардер доверенным на целевом контракте
     * @param target - адрес целевого контаркта
     */
    function _isTrustedByTarget(address target) internal view virtual returns (bool) {
        bytes memory encodedParams = abi.encodeCall(ERC2771Context.isTrustedForwarder, (address(this)));

        bool success;
        uint256 returnSize;
        uint256 returnValue;
        assembly ("memory-safe") { //делаем низкоуровневый вызов функции isTrustedForwarder на целевом контракте
            success := staticcall(gas(), target, add(encodedParams, 0x20), mload(encodedParams), 0, 0x20)
            returnSize := returndatasize()
            returnValue := mload(0)
        }

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
        
        if (gasLeft < request.gas / 63) { //проверяем, что оставшийся после вызова газ меньше, чем EVM оставляет себе по правилу 63/64
            
            assembly ("memory-safe") { //и если меньше, ревертим транзакцию
                invalid() //гарантированно откатывает транзакцию и сжигает весь газ
            }
        }
    }
}