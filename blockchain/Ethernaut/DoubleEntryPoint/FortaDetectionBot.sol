// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IForta {
    function setDetectionBot(address detectionBotAddress) external;
    function notify(address user, bytes calldata msgData) external;
    function raiseAlert(address user) external;
}
contract FortaDectionBot {
    IForta public forta;
    address public cryptoVault;

    constructor(address _forta,address _cryptoVault){
        forta = IForta(_forta); // 등록을 위한 forta
        cryptoVault=_cryptoVault; // 검사를 위한 cryptoVault 주소
    }

    function handleTransaction(address user, bytes calldata msgData) public{ // plyaer, msg.data 이 매개변수로 들어옴
        bytes4 sig = bytes4(msgData[0:4]);
        bytes32 param1;
        address target_addr;
        if(bytes4(abi.encodeWithSignature("delegateTransfer(address,uint256,address)"))==sig){ // delegateTransfer이라면 cryptoVault가 보낸것인지 확인
            bytes calldata test2=msgData[4:];
            for(uint i=0;i<3;i++){
                param1=bytes32(test2[:32]);
                test2=test2[32:];
            }
            target_addr=address(uint160(uint256(param1)));
            if(target_addr == cryptoVault){
                forta.raiseAlert(user);
            }
        }
    }
}
