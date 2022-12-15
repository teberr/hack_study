// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

contract test{
    bytes32 public a = 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;
    bytes32 public b = 0xb10e2d527612073b26eecdfd717e6a320cf44b4afac2b0732d9fcbe2b7fa0cf6;
    bytes32 public c;

    constructor(){
        c=bytes32(uint256(a)-uint256(b)+1);
    }
}

