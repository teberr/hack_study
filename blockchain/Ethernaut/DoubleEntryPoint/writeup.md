https://teberr.notion.site/Ethernaut-DoubleEntryPoint-12d83be9752446adba5f0185ae9b98b2

![DoubleEntryPoint.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/2be5f825-3858-4582-b998-f3c378f39798/DoubleEntryPoint.png)

> 이 단계에서 CryptoVault 컨트랙트는 특별한 함수인 sweepToken을 가지고 있습니다. 이는 컨트랙트에 있는 토큰을 검색할 때 사용되는 일반적인 함수입니다. 이 때 다른 모든 토큰은 sweep할 수 있지만 underlying 토큰은 CryptoVault의 핵심적인 로직 요소이므로 sweep할 수 없습니다.

underlying 토큰은 DoubleEntryPoint 컨트랙트 정의에 구현되어 있는 DET 토큰 인스턴스이며 CryptoVault는 100개의 토큰을 가지고 있습니다. 추가적으로 CryptoVault에는 LegacyToken LGT도 100개 가지고 있습니다.

이 단계에서는 CryptoVault의 버그가 있는 위치를 알아내서 토큰을 전부 탈취하는 것을 막아야 합니다.

어느 유저든 detection bot 컨트랙트를 등록할 수 있는 Forta 컨트랙트가 존재합니다. Forta는  Defi, NFT, 거버넌스, 브릿지 등 Web3 체계에서 가능한한 빠르게 비정상적인 네트워크 위협을 탐지하고 모니터링 할 수 있는 탈중앙화 커뮤니티 기반으로 되어있습니다. 

이 문제의 목표는 detection bot 을 만들고 Forta 컨트랙트에 등록시켜 공격이나 버그 익스플로잇을 예방하는 정확한 경고를 발생시키는 것입니다.
> 
> 
> 힌트
> 
> - double entry point가 토큰 컨트랙트에서 어떻게 진행되는지 고민해봅시다.

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "openzeppelin-contracts-08/access/Ownable.sol";
import "openzeppelin-contracts-08/token/ERC20/ERC20.sol";

interface DelegateERC20 {
  function delegateTransfer(address to, uint256 value, address origSender) external returns (bool);
}

interface IDetectionBot {
    function handleTransaction(address user, bytes calldata msgData) external;
}

interface IForta {
    function setDetectionBot(address detectionBotAddress) external;
    function notify(address user, bytes calldata msgData) external;
    function raiseAlert(address user) external;
}

contract Forta is IForta {
  mapping(address => IDetectionBot) public usersDetectionBots;
  mapping(address => uint256) public botRaisedAlerts;

  function setDetectionBot(address detectionBotAddress) external override {
      usersDetectionBots[msg.sender] = IDetectionBot(detectionBotAddress);
  }

  function notify(address user, bytes calldata msgData) external override {
    if(address(usersDetectionBots[user]) == address(0)) return;
    try usersDetectionBots[user].handleTransaction(user, msgData) {
        return;
    } catch {}
  }

  function raiseAlert(address user) external override {
      if(address(usersDetectionBots[user]) != msg.sender) return;
      botRaisedAlerts[msg.sender] += 1;
  } 
}

contract CryptoVault {
    address public sweptTokensRecipient;
    IERC20 public underlying;

    constructor(address recipient) {
        sweptTokensRecipient = recipient;
    }

    function setUnderlying(address latestToken) public {
        require(address(underlying) == address(0), "Already set");
        underlying = IERC20(latestToken);
    }

    /*
    ...
    */

    function sweepToken(IERC20 token) public {
        require(token != underlying, "Can't transfer underlying token");
        token.transfer(sweptTokensRecipient, token.balanceOf(address(this)));
    }
}

contract LegacyToken is ERC20("LegacyToken", "LGT"), Ownable {
    DelegateERC20 public delegate;

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }

    function delegateToNewContract(DelegateERC20 newContract) public onlyOwner {
        delegate = newContract;
    }

    function transfer(address to, uint256 value) public override returns (bool) {
        if (address(delegate) == address(0)) {
            return super.transfer(to, value);
        } else {
            return delegate.delegateTransfer(to, value, msg.sender);
        }
    }
}

contract DoubleEntryPoint is ERC20("DoubleEntryPointToken", "DET"), DelegateERC20, Ownable {
    address public cryptoVault;
    address public player;
    address public delegatedFrom;
    Forta public forta;

    constructor(address legacyToken, address vaultAddress, address fortaAddress, address playerAddress) {
        delegatedFrom = legacyToken;
        forta = Forta(fortaAddress);
        player = playerAddress;
        cryptoVault = vaultAddress;
        _mint(cryptoVault, 100 ether);
    }

    modifier onlyDelegateFrom() {
        require(msg.sender == delegatedFrom, "Not legacy contract");
        _;
    }

    modifier fortaNotify() {
        address detectionBot = address(forta.usersDetectionBots(player));

        // Cache old number of bot alerts
        uint256 previousValue = forta.botRaisedAlerts(detectionBot);

        // Notify Forta
        forta.notify(player, msg.data);

        // Continue execution
        _;

        // Check if alarms have been raised
        if(forta.botRaisedAlerts(detectionBot) > previousValue) revert("Alert has been triggered, reverting");
    }

    function delegateTransfer(
        address to,
        uint256 value,
        address origSender
    ) public override onlyDelegateFrom fortaNotify returns (bool) {
        _transfer(origSender, to, value);
        return true;
    }
}
```

# 코드 분석 및 공격 설계

### DoubleEntryPoint

이번 문제에서는 instance를 받아오면 얻을 수 있는 컨트랙트가 DoubleEntryPoint 컨트랙트이다.

```solidity
contract DoubleEntryPoint is ERC20("DoubleEntryPointToken", "DET"), DelegateERC20, Ownable {
    address public cryptoVault;
    address public player;
    address public delegatedFrom;
    Forta public forta;

    constructor(address legacyToken, address vaultAddress, address fortaAddress, address playerAddress) {
        delegatedFrom = legacyToken;
        forta = Forta(fortaAddress);
        player = playerAddress;
        cryptoVault = vaultAddress;
        _mint(cryptoVault, 100 ether);
    }

    modifier onlyDelegateFrom() {
        require(msg.sender == delegatedFrom, "Not legacy contract");
        _;
    }

    modifier fortaNotify() {
        address detectionBot = address(forta.usersDetectionBots(player));

        // Cache old number of bot alerts
        uint256 previousValue = forta.botRaisedAlerts(detectionBot);

        // Notify Forta
        forta.notify(player, msg.data);

        // Continue execution
        _;

        // Check if alarms have been raised
        if(forta.botRaisedAlerts(detectionBot) > previousValue) revert("Alert has been triggered, reverting");
    }

    function delegateTransfer(
        address to,
        uint256 value,
        address origSender
    ) public override onlyDelegateFrom fortaNotify returns (bool) {
        _transfer(origSender, to, value);
        return true;
    }
}
```

이 인스턴스를 조금 살펴보면 

1. ERC20을 상속받고 있으므로 DoubleEntryPoint 인스턴스는 “DET”라는 이름의 토큰이다.
2. 상태변수로 다음과 같은 주소를 가지고 있으며 public으로 되어있어 값을 가져올 수 있다.
    1. cryptoVault 컨트랙트 주소
    2. player (유저) 주소
    3. delegateFrom (legacyToken 컨트랙트 주소)
    4. Forta 컨트랙트 주소 
3. delegateTransfer 함수를 가지고 있으며 이 함수는 두개의 모디파이어를 가지고 있다.
    1. onlyDelegateFrom - legacyToken 컨트랙트에서 호출해야 함.
    2. fortaNotify - forta 컨트랙트의 player주소와 매핑되어 있는 Detectionbot을 가져와 notify를 통해 Detectionbot.handleTransaction 을 실행시켜 이상이 감지되었다면 forta의 raiseAlert(player)를 작동시켜 previousValue보다 높게하여 이상을 탐지하는 모디파이어

로 구성이 되어있다. 

우리가 목표로 하는것은 3.b의 Detectionbot을 작성할 것이다. **이 Detectionbot은 CryptoVault의 underlying토큰을 탈취하려는 이상을 탐지하면 raiseAlert(player)를 작동시키는 컨트랙트**로 작성되어야 한다.

이 때 underlying 토큰은 문제에서 알려주었듯이 DET 토큰이며 이 토큰은 CryptoVault에서 SweepToken 함수로 Sweep이 불가능하지만 이를 탈취할 수 있는 방법이 있다.

### CryptoVault, LegacyToken

CryptoVault 컨트랙트를 살펴보자.

```solidity
contract CryptoVault {
    address public sweptTokensRecipient;
    IERC20 public underlying;

    constructor(address recipient) {
        sweptTokensRecipient = recipient;
    }

    function setUnderlying(address latestToken) public {
        require(address(underlying) == address(0), "Already set");
        underlying = IERC20(latestToken);
    }

    /*
    ...
    */

    function sweepToken(IERC20 token) public {
        require(token != underlying, "Can't transfer underlying token");
        token.transfer(sweptTokensRecipient, token.balanceOf(address(this)));
    }
}
```

underlying 토큰을 설정하는 setUnderlying 함수를 살펴보면 require문으로 이미 설정이 되어있으면 재설정이 불가능한 것을 알 수 있다.

우리는 문제에서 알려주듯이 underlying 토큰이 DET 토큰인 것을 알고 있으므로 이 함수는 실질적으로 사용이 불가능하다. 따라서 이 CryptoVault에서 사용할 수 있는 함수는 sweepToken(IERC20 token)인데 이 함수는 CryptoVault에 존재하는 IERC20토큰을 전송하는 token.transfer를 실행시킨다.

문제에서 CryptoVault에는 DET(underlying)과 LegacyToken이 존재한다고 하였다… LegacyToken의 transfer함수를 잠시 살펴보자.

```solidity
contract LegacyToken is ERC20("LegacyToken", "LGT"), Ownable {
    DelegateERC20 public delegate;
		/**/
    function transfer(address to, uint256 value) public override returns (bool) {
        if (address(delegate) == address(0)) {
            return super.transfer(to, value);
        } else {
            return delegate.delegateTransfer(to, value, msg.sender);
        }
    }
}
```

delegateERC20 을 상속받는 delegate의 delegateTransfer를 실행시킨다. 그런데 이 delegateERC20을 상속받는 컨트랙트는 우리가 처음 살펴본 DoubleEntryPoint 컨트랙트이다. 

즉 CryptoVault에서 sweepToken(LegacyToken)이 실행되면 다음과 같이 수행된다.

1. sweepToken(LegacyToken)에서 LegacyToken.transfer(recipient,100)이 수행된다.
2. LegacyToken.transfer에서 DoubleEntryPoint.delegateTransfer(recipient,100,CryptoVault)가 수행된다.
3. DoubleEntryPoint.delegateTransfer에서 DoubleEntryPoint.transfer(CryptoVault,recipient,100)이 수행된다.

따라서 cryptoVault에서 sweepToken(LegacyToken)이 수행되면 LegacyToken이 전송되는 것이 아닌 DET토큰(underlying)이 탈취당하는 것을 볼 수 있다. 이는 문제에서 나와있듯 의도한 상황이 아닌 비정상적인 ‘버그’이므로 이를 탐지하는 컨트랙트를 작성하면 된다.

### DetectionBot

```solidity
contract Forta is IForta {
  mapping(address => IDetectionBot) public usersDetectionBots;
  mapping(address => uint256) public botRaisedAlerts;

  function setDetectionBot(address detectionBotAddress) external override {
      usersDetectionBots[msg.sender] = IDetectionBot(detectionBotAddress);
  }

  function notify(address user, bytes calldata msgData) external override {
    if(address(usersDetectionBots[user]) == address(0)) return;
    try usersDetectionBots[user].handleTransaction(user, msgData) {
        return;
    } catch {}
  }

  function raiseAlert(address user) external override {
      if(address(usersDetectionBots[user]) != msg.sender) return;
      botRaisedAlerts[msg.sender] += 1;
  } 
}

interface IDetectionBot {
    function handleTransaction(address user, bytes calldata msgData) external;
}
```

DetectionBot 컨트랙트는 handleTransaction 함수가 존재해야 하며 이 함수에서 버그를 탐지하면 Forta의 raiseAlert를 실행시키면 된다.

그러면 기본적인 DetectionBot의 토대는 다음과 같다.

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IDetectionBot {
    function handleTransaction(address user, bytes calldata msgData) external;
}

interface IDoubleEntryPoint{
		function forta()external returns(address);
    function delegateTransfer(address to,uint256 value,address origSender) external returns (bool);
}

interface IForta {
    function setDetectionBot(address detectionBotAddress) external;
    function notify(address user, bytes calldata msgData) external;
    function raiseAlert(address user) external;
}
contract FortaDectionBot is IDetectionBot{
    IDoubleEntryPoint public target;
    IForta public forta;

    constructor(address _target){
        target=IDoubleEntryPoint(_target);
        forta = IForta(address(target.forta()));
    }

    function handleTransaction(address user, bytes calldata msgData) override public{ // plyaer, msg.data 이 매개변수로 들어옴
        forta.raiseAlert(user);
    }
}
```

이제 function handleTransaction(address user, bytes calldata msgData) 에서 탐지를 어떻게 할지를 결정하면 된다.

먼저 내 DetectionBot이 언제 무슨 매개변수를 받으며 호출되는지를 살펴보자. DoubleEntryPoint 컨트랙트에서 delegateTransfer 함수가 실행될 때 모디파이어인 fortaNotify()에서 실행이 된다.

```solidity
contract DoubleEntryPoint is ERC20("DoubleEntryPointToken", "DET"), DelegateERC20, Ownable {
		/*

		*/

    modifier onlyDelegateFrom() {
        require(msg.sender == delegatedFrom, "Not legacy contract");
        _;
    }

    modifier fortaNotify() {
        address detectionBot = address(forta.usersDetectionBots(player));
        // Cache old number of bot alerts
        uint256 previousValue = forta.botRaisedAlerts(detectionBot);
        // Notify Forta
        forta.notify(player, msg.data);
        // Continue execution
        _;
        // Check if alarms have been raised
        if(forta.botRaisedAlerts(detectionBot) > previousValue) revert("Alert has been triggered, reverting");
    }

    function delegateTransfer(
        address to,
        uint256 value,
        address origSender
    ) public override onlyDelegateFrom fortaNotify returns (bool) {
        _transfer(origSender, to, value);
        return true;
    }
}
```

msgData 값에서 공격이 발생하는지 탐지를 해야하는데 msgData는 CrypToVault 컨트랙트에서 LegacyToken을 sweepToken하려고 할 때 DoubleEntryPoint에서 fortaNotify로 인하여 발생해야 한다. 그래서 직접 VM에서 각 컨트랙트를 Deploy 후 확인해 보았다.

## 테스트를 위한 세팅

문제 코드를 그대로 복사하여 VM에서 배포할 예정이다. 물론 DetectionBot은 조금 수정하였다.

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IDetectionBot {
    function handleTransaction(address user, bytes calldata msgData) external;
}

interface IDoubleEntryPoint{
    function cryptoVault()external returns(address);
    function delegatedFrom()external returns(address);
    function forta()external returns(address);
    function delegateTransfer(address to,uint256 value,address origSender) external returns (bool);
}

interface IForta {
    function setDetectionBot(address detectionBotAddress) external;
    function notify(address user, bytes calldata msgData) external;
    function raiseAlert(address user) external;
}
contract FortaDectionBot is IDetectionBot{
    IDoubleEntryPoint public target;
    IForta public forta;
    address public delegatedFrom;
    address public cryptoVault;
    bytes public result ;

    function initialize(address _target)public{
        target=IDoubleEntryPoint(_target);
        forta = IForta(address(target.forta()));
        cryptoVault=target.cryptoVault();
        delegatedFrom = target.delegatedFrom();
    }
    function register()public{
        forta.setDetectionBot(address(this));
    }
    function handleTransaction(address user, bytes calldata msgData) override public{ // plyaer, msg.data 이 매개변수로 들어옴
        result = msgData;
        //forta.raiseAlert(address(this));
        //forta.raiseAlert(user);
    }
}
```

raiseAlert가 일어나면 revert가 일어나므로 작동하는지만 확인한 후 주석처리하고 다시 배포해주었다.

![VM- DoubleEntryPoint.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/d2161489-1f74-4642-bd77-da1fcd8938c8/VM-_DoubleEntryPoint.png)

이 때 DoubleEntryPoint를 배포할 때 player의 주소를 작성한 FortaDetectionbot 주소로 하였다. 그 이유는 Forta에 내 FortaDetectionBot을 등록할 것인데 이 때 등록하는 것을 FortaDetectionBot으로 진행할 것이므로 DoubleEntryPoint의 fortaNotify 실행시 전달되는 player의 주소가 FortaDetectionbot 주소여야 작동이 제대로 되기 때문이다. (실제 환경에서는 player가 내 메타마스크 주소이므로 콘솔에서 forta에 등록해주어야한다.) 

![VM - underlying.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/61b153c2-e76f-493c-9459-22f9ae476ba1/VM_-_underlying.png)

DoubleEntryPoint 컨트랙트의 주소가 DET 토큰 주소이므로 CryptoVault에서 underlying 토큰으로 지정해준다.

![VM-DetectionBot 초기화.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/52d22643-f557-4cb0-8250-242fbd833e75/VM-DetectionBot_%EC%B4%88%EA%B8%B0%ED%99%94.png)

initialize로 DoubleEntryPoint 인스턴스의 주소를 입력해준후 register로 Forta에 등록해준다.

![VM- forta 등록.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/2416e00e-f184-4467-8894-5086e571fc24/VM-_forta_%EB%93%B1%EB%A1%9D.png)

forta에서 내 DetectionBot 컨트랙트를 넣어보면 잘 등록이 되어있는 것을 볼 수 있다. 

![VM - minting.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/8d4b1a0d-6d1e-4a38-8a2a-95bdb6673250/VM_-_minting.png)

CryptoVault에도 LegacyToken이 존재해야 sweepToken(LegacyToken)이 가능하므로 mint 해준 후 delegateToNewContract도 DoubleEntryPoint 로 설정해준다.

이제 모든 준비가 끝났으므로 SweepToekn(LegacyToken)을 실행했을 때 어떤 msg.data값이 나오는지 확인해보자.

![sweep후 bytes.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/e93f23ab-797a-416d-9c38-b5b1b05297b2/sweep%ED%9B%84_bytes.png)

sweepToken을 해준 후 bytes값을 확인해보면 다음과 같다.

```solidity
bytes: 0x9cd1a12100000000000000000000000083b26d6a3d3fabd9f0a5f1d69dca1ce6cc4ea39a00000000000000000000000000000000000000000000000000000000000003e8000000000000000000000000e2899bddfd890e320e643044c6b95b9b0b84157a
```

![Untitled](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/c6bb92fc-ca50-4fa9-b29e-79e3273b0abf/Untitled.png)

첫 4바이트가 0x9cd1a121인데 이는 delegateTransfer임을 알 수 있다. 다음 32바이트씩 인자를보자

00000000000000000000000083b26d6a3d3fabd9f0a5f1d69dca1ce6cc4ea39a는 sweptToken즉 목적지이다. 

00000000000000000000000000000000000000000000000000000000000003e8은 value이다.

000000000000000000000000e2899bddfd890e320e643044c6b95b9b0b84157a은 CryptoVault의 주소이다.

따라서 이 msg.data를 다시 되돌려보면

- CryptoVault의 delegate.delegateTransfer(to, value, msg.sender) 이고 인자도 넣어주면
- delegate.delegateTransfer(sweptTokenRecipient, value, CryptoVault)가 된다.

즉 msg.data는 DoubleEntryPoint의 delegateTransfer를 호출하는 데이터라고 볼 수 있다. 이 msg.data를 해체해서 공격으로 인식하려면 어떻게 조건을 걸어야하는지 다시 기억해보자.

1. CryptoVault에서 legacyToken을 sweepToken 을 실행
2. legacyToken에서 delegate.delegateTransfer 을 실행
3. 따라서 msg.data가 delegateTransfer(sweptTokenRecipient, value, CryptoVault)인 상태에서 이를 notify의 인자로 전달해준다.

우리는 CryptoVault에서 legacyToken을 sweepToken함수를 통해 legacyToken의 delegate.delegateTransfer(to,value,msg.sender)가 실행되는 것을 탐지하면 된다.

즉 함수 시그니쳐가 delegateTransfer일 때 세번째 인자가 cryptovault인 것을 감지하면 되므로 이를 [msg.data](http://msg.data) 에서 추출하여 탐지하면 된다.

### bytes 자르기

우리가 받을 데이터는 calldata 이므로 배열의 형태로 slice가 가능하다.

```solidity
// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.5;

contract test{

    bytes4 public sig ;
    bytes32 public param1;
    address public target_addr;

    function sigtest(bytes calldata test)public {
        sig = bytes4(test[0:4]);
    }

    function paramtest(bytes calldata test)public{
        bytes calldata test2=test[4:];
        for(uint i=0;i<3;i++){
            param1=bytes32(test2[:32]);
            test2=test2[32:];
        }

    }

    function addr_test()public{
        target_addr=address(uint160(uint256(param1)));
    }
}
```

따라서 calldata 형태의 msg.data를 받았을 시 [0:4]까지는 delegatetransfer의 signature 값을 추출할 수 있고 반복문을 통해 마지막 32바이트값을 가져올 수 있다.

![bytes 자르기 test.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/d59ab964-3763-4cb4-a7cf-5c31d3a30f0a/bytes_%EC%9E%90%EB%A5%B4%EA%B8%B0_test.png)

실제로 bytes를 잘라서 sig값과 마지막 파라미터를 주소로 변환하는것 까지 성공하는 것을 테스트 확인할 수 있다.

# 공격

그러면 calldata인 msg.data를 사용한 테스트를 완료하였으므로 실제 네트워크에 DetectionBot을 배포하여 등록해보자.

 

```solidity
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
```

내 VM에 배포해야하는 상황과는 다르게 실제 인스턴스에서는 handleTransaction(player,msg.data)로 이루어져 forta에 등록된 user가 내 주소여야 하므로 Bot에서 forta에 등록하는 코드는 제외시켰다. 또한 테스트를 위해 필요했던 다른 컨트랙트의 인터페이스를 제외하고 필요한 변수만을 남겼다.

forta에 직접 접근하는 abi를 콘솔에서 제공해주고 있지 않으므로 sendTransaction의 data를 통해서 함수 시그니쳐 + 인자값으로 전송해주어야 한다. forta에 봇을 등록하기위해 전송해주어야 하는 인자는 내 DetectionBot 컨트랙트의 주소이므로 먼저 Deploy를 해준다.

```solidity
await contract.forta()
'0x34340B998429AE3E76Da0A9c6258982aB58277cc'
await contract.cryptoVault()
'0x36D4d106173731033f1aB57441944A8A821d09B5'
```

![봇 배포.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/c316cfc8-39e4-4d2f-90cd-cae95e6c9629/%EB%B4%87_%EB%B0%B0%ED%8F%AC.png)

그리고 나면 FortaDetectionBot의 주소가 생성된다.

 

![Untitled](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/9e8c12ba-6435-4750-aad7-747eed3844a5/Untitled.png)

```solidity
0x5bF1B978BFa10d45a3C88631751e53EEa1e1fcDF
```

이를 이용해서 setDetectionBot(0x5bF1B978BFa10d45a3C88631751e53EEa1e1fcDF)를 data로 변환해보자.

![Untitled](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/41f3f46f-66c8-462a-bf4f-29a56aafd3a5/Untitled.png)

먼저 함수 시그니쳐는 0x9e927c68이다. 

이제 인자로 이 함수 시그니쳐 뒤에 32바이트 패딩을 하여 주소를 붙여주면 된다. 주소는 왼쪽에 0을 채우는 left padding을 하므로 

0000000000000000000000005bF1B978BFa10d45a3C88631751e53EEa1e1fcDF 가된다. 따라서 최종적인 data값은

```solidity
0x9e927c680000000000000000000000005bF1B978BFa10d45a3C88631751e53EEa1e1fcDF
```

가 된다. 이제 트랜잭션을 발생시켜 forta에 내 DetectionBot을 등록시키자.

![트랜잭션 발생.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/d42a0c01-85e6-408e-8fbb-218bed6d2af7/%ED%8A%B8%EB%9E%9C%EC%9E%AD%EC%85%98_%EB%B0%9C%EC%83%9D.png)

이제 봇을 등록시켰으므로 이상 CryptoVault에서 sweepToken(legacyToken)이 발생하면 봇이 감지를 하게 된다. 문제 조건을 달성하였으므로 제출하면 성공했음을 알 수 있다.

![Untitled](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/0e3ac131-ea11-406f-b4f4-931b9eaa191b/Untitled.png)

# 후기

일반적으로 두개의 진입점을 갖는 것은 꽤나 영향이 큰 문제이다. 하나의 컨트랙트당 하나의 토큰만을 갖는 것을 전제로 하기 때문이다. 조금 더 자세히 알기 위해서는 [https://blog.openzeppelin.com/compound-tusd-integration-issue-retrospective/](https://blog.openzeppelin.com/compound-tusd-integration-issue-retrospective/)를 참고하여 보면 좋다.
