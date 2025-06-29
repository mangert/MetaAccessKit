// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

abstract contract MetaTxModule is EIP712 {
    using ECDSA for bytes32;

    mapping(address => uint256) public nonces;

    bytes32 private constant META_TX_TYPEHASH = keccak256(
        "MetaTransaction(bytes callData,uint256 nonce)"
    );

    constructor(string memory name, string memory version)
        EIP712(name, version)
    {}

    function _verifyAndExecute(
        address signer,
        bytes calldata callData,
        uint256 nonce,
        bytes calldata signature
    ) internal {
        require(nonces[signer] == nonce, "MetaTx: invalid nonce");

        bytes32 structHash = keccak256(
            abi.encode(
                META_TX_TYPEHASH,
                keccak256(callData),
                nonce
            )
        );

        bytes32 digest = _hashTypedDataV4(structHash);

        address recovered = ECDSA.recover(digest, signature);
        require(recovered == signer, "MetaTx: invalid signature");

        nonces[signer] += 1;

        (bool success, bytes memory returndata) = address(this).call(callData);
        require(success, "MetaTx: call failed");
    }
}
