// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {IERC20Permit} from "./IERC20Permit.sol";

import "@openzeppelin/contracts/token/ERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "@openzeppelin/contracts/utils/Nonces.sol";

abstract contract ERC20Permit is ERC20, IERC20Permit, EIP712{

    mapping(address => nonces) private _nonces;
      
    bytes32 private constant PERMIT_TYPEHASH = keccak256
        ("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
    
    constructor(string memory name) EIP712(name, "1") {};

    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external virtual {
        require(block.timestamp <= deadline, "expired"); //TODO - сделать кастомную ошибку
        
        bytes32 structHash = keccak256(
            abi.encode(
                PERMIT_TYPEHASH,
                owner,
                spender,
                value,
                _useNonce(owner),
                deadline
            )
        );

        bytes32 hash = _hashTypedDataV4(structHash);

        address signer = ECDSA.recover(hash, v, r, s);

        require(signer == owner, "not an owner"); //TODO - сделать кастомную ошибку
        _approve(owner, spender, value);
            
        }


    }

    function nonces(address owner) external view returns (uint256) {};
    
    function DOMAIN_SEPARATOR() external view returns (bytes32) {};


    
}