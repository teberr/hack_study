https://honey-push-30b.notion.site/Ethernaut-Fallback-835a6262797044518715d0026839164d
![Fallback.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/b0f8af91-8d56-4005-bcd4-43be56d0b375/Fallback.png)

튜토리얼 hello ethernaut을 완료하면 진행할 수 있는 사실상 첫번째 CTF 문제 Fallback이다. 

> 
> 
> 
> 아래에 있는 코드를 자세히 살펴보세요
> 
> 이번 문제를 해결하기 위해서는
> 
> 1. 컨트랙트의 ownership 권한을 획득해야합니다.
> 2. 그리고 자산(balance)를 0으로 만들어야 합니다.
> 
> 힌트
> 
> - ABI를 이용해서 어떻게 ether를 보낼지 고민해보세요
> - ABI 외부로 어떻게 ether를 보낼지
> - help() 명령어를 참고해서 wei/ether 서로 변환하는 것을 참고하세요
> - Fallback 함수

코드는 아래와 같다.

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import '@openzeppelin/contracts/math/SafeMath.sol';

contract Fallback {

  using SafeMath for uint256; //오버플로우 및 언더플로우 금지
  mapping(address => uint) public contributions; // 주소별 이더양을 저장할 contribution
  address payable public owner; // 이더의 전송이 가능한 owner 주소

  constructor() public {
    owner = msg.sender; // owner는 요청자. 
    contributions[msg.sender] = 1000 * (1 ether); // msg.sender의 이더는 1000개로 초기화
  }

  modifier onlyOwner { // 요청자가 owner여야함
        require(
            msg.sender == owner, 
            "caller is not the owner"
        );
        _;
    }

  function contribute() public payable { 
    require(msg.value < 0.001 ether); // 요청한 값이 0.001이더보다 작아야함
    contributions[msg.sender] += msg.value; // 요청자에게 요청한 값만큼 이더 추가
    if(contributions[msg.sender] > contributions[owner]) { //만약 요청자가 owner보다 이더가 많으면
      owner = msg.sender; //요청자가 owner가됨
    }
  }

  function getContribution() public view returns (uint) {
    return contributions[msg.sender]; //요청자가 소유한 이더의양 반환
  }

  function withdraw() public onlyOwner { // owner만 출금이가능함
    owner.transfer(address(this).balance); // owner의 주소로 이 컨트랙트의 balance만큼 이더를 보냄
  }

  receive() external payable { // receive함수는 이 컨트랙트의 주소로 이더를 보낼시에 작동
    require(msg.value > 0 && contributions[msg.sender] > 0); // 요청자의 value가 0보다 크고 요청자 주소의 이더양이 0보다 크면
    owner = msg.sender;// 요청자가 owner가 됨.
  }
}
```

# Fallback 함수 (Receive)

이 스마트 컨트랙트 코드에서는  생성자, 모디파이어, 세개의 함수, receive함수가 존재한다.

이 때 receive 함수에 대해서 조금 자세히 설명하면 Receive함수는 솔리디티 버전 0.6이후에 fallback 함수에서 분리된 함수로 먼저 fallback 함수부터 설명을 해야한다.

Fallback 함수는 대비책 함수로

1. 스마트 컨트랙트가 이더를 받을 수 있게 해줌
2. 스마트 컨트랙트가 이더를 받고 나서 특정 행동(”잘받았어요 보내기”)등을 할 수 있게 해줌
3. call로 존재하지 않는 함수를 호출한다면(A를 호출했는데 A가 없음, 그러면 fallback 함수가 우리 그런 함수 없는데용? 같은 특정 행동을 취하게 할 수 있음 )

외부에서 호출하는 함수이므로 external이 필수이고 이더를 주고받아야 하므로 payable을 써줘야 함

0.6이후에는 receive와 fallback으로 나뉘어 지며 receive는 순수하게 이더만 받을 때 작동(1)

함수를 실행하면서 이더를 보낼때(3), 불려진 함수가 없을 때 작동함 fallback 함수

즉 receive함수는 call함수로 이더만 보낼때 작동하고, fallback은 call함수로 이더도 보내면서 함수도 실행할 때 작동함 

외부에서 컨트랙트의 주소로 이더를 보냈을 때 그리고 함수를 호출하지 않을 때 실행되는 함수이다. 

즉 컨트랙트의 입장에서는 이더를 받기만 하고 실행되는 함수가 없다면 recieve 함수가 실행이 되므로 문제 컨트랙트의 receive 함수는 외부에서 이 Fallback 컨트랙트 주소로 이더를 보내면 실행이 된다.

```solidity
  receive() external payable { // receive함수는 이 컨트랙트의 주소로 이더를 보낼시에 작동
    require(msg.value > 0 && contributions[msg.sender] > 0); // 요청자의 value가 0보다 크고 요청자 주소의 이더양이 0보다 크면
    owner = msg.sender;// 요청자가 owner가 됨.
  }
}
```

# 코드 분석 및 공격 설계

이번 문제의 목적은 두가지다.

1. 컨트랙트의 ownership 권한을 획득
2. 그리고 자산(balance)를 0으로 만들기

첫번째 ownership 권한을 획득하기 위해서 owner의 권한을 얻을 수 있는 함수들을 살펴보면 constructor(생성자), contribute 함수, receive 함수 세가지가 있다.

```solidity
  constructor() public {
    owner = msg.sender; // owner는 요청자. 
    contributions[msg.sender] = 1000 * (1 ether); // msg.sender의 이더는 1000개로 초기화
  }
```

생성자는 이 컨트랙트를 생성한 주소가 owner가 되며 1000이더로 초기화 해준다. 우리가 get new Instance를 하면 ethernaut 측에서 이 컨트랙트를 생성해 주므로 우리의 메타마스크 주소로 이 생성자 함수를 실행 시키기에는 무리가 있다.

```solidity
  function contribute() public payable { 
    require(msg.value < 0.001 ether); // 요청한 값이 0.001이더보다 작아야함
    contributions[msg.sender] += msg.value; // 요청자에게 요청한 값만큼 이더 추가
    if(contributions[msg.sender] > contributions[owner]) { //만약 요청자가 owner보다 이더가 많으면
      owner = msg.sender; //요청자가 owner가됨
    }
  }
```

contribute 함수 이며 public 이므로 외부에서 실행이 가능하다. 이 함수는 내부에 조건(require)이 있는데 이더의 양(msg.value)이 0.001보다 작아야 한다. 

이 조건을 통과하면 요청한 주소(msg.sender)에게 요청한 값만큼 증가시켜주고 이 결과로 msg.sender가 owner보다 더 많은 이더를 가지게 되면 msg.sender가 owner가 된다.

0.001이더보다 작게 보내야하므로 0.0009 이더씩 늘린다고 가정했을 때 1000/0.0009=1,111,111.111… 이므로 총 1,111,112번 보내야 한다. 백만번이기 때문에 스크립트를 작성하여 이 함수를 실행시켜 owner 권한을 얻는 방법이 있겠고 다른 방법이 있는지 살펴보자

```solidity
 receive() external payable { // receive함수는 이 컨트랙트의 주소로 이더를 보낼시에 작동
    require(msg.value > 0 && contributions[msg.sender] > 0); // 요청자의 value가 0보다 크고 요청자 주소의 contribution에 있는 이더양이 0보다 크면
    owner = msg.sender;// 요청자가 owner가 됨.
  }
}
```

이 컨트랙트로 이더를 보내면 실행 되는 receive 함수이다. 보낸 이더의 양이 0보다 크고 보낸 주소의 contribution 에 저장된 이더 양이 0보다 크면 owner 권한을 얻게 된다.

즉 내 메타마스크 주소에 연결된 contribution 값이 0보다 크게 만든 후 이 컨트랙트에 이더를 보내면 owner 권한을 얻을 수 있다.

그러면 ownership 권한을 얻었으므로 다음 목표인 자산(balance)를 0으로 만들어야 한다. 

balance에 관련된 함수는 withdraw()함수가 있다.

```solidity
  function withdraw() public onlyOwner { // owner만 출금이가능함
    owner.transfer(address(this).balance); // owner의 주소로 이 컨트랙트의 balance만큼 이더를 보냄
  }
```

owner에게 이 컨트랙트의 balance를 전송하는 함수이다. 모디파이어로 onlyOwner가 설정되어 있기에 onlyOwner 모디파이어를 조금 살펴보면

```solidity
  modifier onlyOwner { // 요청자가 owner여야함
        require(
            msg.sender == owner, 
            "caller is not the owner"
        );
        _;
    }
```

요청자의 주소가 owner인지 확인하는 모디파이어다.  

즉 owner권한을 얻고 withdraw()함수를 실행시키면 내 주소로 이 컨트랙트의 balance만큼 이더를 받아 balance를 0으로 만들 수 있다.

결국 이 문제의 목적은 컨트랙트의 balance를 0으로 만드는 것이 최종 목적이다. (앞의 ownership 권한을 획득하라는 것은 말하지 않았더라도 withdraw함수의 모디파이어 때문에 했어야 함) 다음과 같은 과정을 거쳐서 공격하면 된다.

1. contribute 함수를 호출하여 내 메타마스크 주소의 contribution 값을 0보다 크게 설정
2. 컨트랙트에 0.00001이더를 보내(0보다 크기만 하면 됨) recieve 함수를 호출하여 owner가 된다.
3. withdraw 함수를 호출하여 이 컨트랙트의 balance를 0으로 만든다. 

# 익스플로잇

![시작.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/101fa2f4-10da-4cf1-8995-c0a568a9f2bb/%EC%8B%9C%EC%9E%91.png)

get new Instance 버튼을 눌러서 문제를 시작하자. get new Instance 버튼을 누르면 트랜잭션이 발생하며 메타마스크에서 트랜잭션 확인을 눌러줘야한다.

![instance.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/6bd2d85a-191b-4d28-84b8-e003972795d3/instance.png)

트랜잭션 확인 후 잠시 기다리면 인스턴스 생성이 완료되고 인스턴스 주소가 나온다.

![인스턴스 생성.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/009e22ee-5d38-4b89-b3f9-0aafef12bb15/%EC%9D%B8%EC%8A%A4%ED%84%B4%EC%8A%A4_%EC%83%9D%EC%84%B1.png)

=> Instance address 이게 컨트랙트의 주소이므로 기억해놔야한다.

0xaDd0ABA29f4B1331557Bb1B1a0aA8735d2ec5629

# ethernaut의 컨트랙트 구조

help()명령어를 통해서 어떤 명령어를 쓸 수 있는지 살펴보면 

| (index) | Value |
| --- | --- |
| player | 'current player address' |
| ethernaut | 'main game contract' |
| level | 'current level contract address' |
| contract | 'current level contract instance (if created)' |
| instance | 'current level instance contract address (if created)' |
| version | 'current game version' |
| getBalance(address) | 'gets balance of address in ether' |
| getBlockNumber() | 'gets current network block number' |
| sendTransaction({options}) | 'send transaction util' |
| getNetworkId() | 'get ethereum network id' |
| toWei(ether) | 'convert ether units to wei' |
| fromWei(wei) | 'convert wei units to ether' |

player를 통해 사용자의 메타마스크 주소를 알 수 있고

ethernaut을 통해 이 게임의 메인 컨트랙트를 알 수 있으며

level을 통해 현재 게임의 단계(여기서는 1단계)의 컨트랙트를 알 수 있고

contract를 통해 현재 단계의 컨트랙트 인스턴스를 

instance를 통해 현재 단계의 컨트랙트 인스턴스 주소를 알 수 있다.

각 주소를 알아내보면

```jsx
player
'0x83b26d6A3D3FaBd9F0A5f1d69DCA1CE6cc4eA39a'
ethernaut.address
'0xD991431D8b033ddCb84dAD257f4821E9d5b38C33'
level
'0x9CB391dbcD447E645D6Cb55dE6ca23164130D008'
contract.address
'0xaDd0ABA29f4B1331557Bb1B1a0aA8735d2ec5629'
instance
'0xaDd0ABA29f4B1331557Bb1B1a0aA8735d2ec5629'
```

위와 같다. 컨트랙트의 주소가 우리가 생성한 instance의 주소이므로 우리는 instance를 생성할 때 컨트랙트를 새로 생성함을 알 수 있다.

그런데 contract와 instance 에서 사용할 수 있는 함수들을 보면 조금 다르다

contract에서 사용할 수 있는 함수들은

![컨트랙트에서 사용할 수 있는 함수.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/9d3e6f13-a1d6-4b0c-b446-8b1176cdaacf/%EC%BB%A8%ED%8A%B8%EB%9E%99%ED%8A%B8%EC%97%90%EC%84%9C_%EC%82%AC%EC%9A%A9%ED%95%A0_%EC%88%98_%EC%9E%88%EB%8A%94_%ED%95%A8%EC%88%98.png)

컨트랙트 코드에서 보았던 함수들 public 함수들인 contribute,getContribution,withdraw가 사용이 가능하지만

instance에서 사용할 수 있는 함수들은

![instance에서 사용할 수 있는 함수.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/12c6d907-2429-4c16-bd42-607a56274360/instance%EC%97%90%EC%84%9C_%EC%82%AC%EC%9A%A9%ED%95%A0_%EC%88%98_%EC%9E%88%EB%8A%94_%ED%95%A8%EC%88%98.png)

컨트랙트 코드에서 보았던 public 함수들을 사용할 수 없다.

즉 instance가 생성이 되면 우리는 contract를 통해서instance에 접근하는것이 가능하므로 

instance ←——→contract(abi) ←———> 사용자로 되어있음을 확인할 수 있다.

이 때 contract의 owner는 이 인스턴스를 생성한 주소이므로 이 인스턴스를 생성한 주소를 확인하면

```jsx
await contract.owner()
'0x9CB391dbcD447E645D6Cb55dE6ca23164130D008'
------------------------------------------------------------------
player
'0x83b26d6A3D3FaBd9F0A5f1d69DCA1CE6cc4eA39a'
ethernaut.address
'0xD991431D8b033ddCb84dAD257f4821E9d5b38C33'
level
'0x9CB391dbcD447E645D6Cb55dE6ca23164130D008'
contract.address
'0xaDd0ABA29f4B1331557Bb1B1a0aA8735d2ec5629'
instance
'0xaDd0ABA29f4B1331557Bb1B1a0aA8735d2ec5629'
```

level의 주소와 같음을 알 수 있다.

즉 구조는

ethernaut —→ level —> instance ←—→contract(abi)←—> 사용자 로 구성이 되어있으며 우리는 contract를 이용해서 instance에 접근하게 된다.

그럼 이제 공격 과정을 진행하면 된다.

1. contribute 함수를 호출하여 내 메타마스크 주소의 contribution 값을 0보다 크게 설정
2. 컨트랙트에 0.00001이더를 보내(0보다 크기만 하면 됨) recieve 함수를 호출하여 owner가 된다.
3. withdraw 함수를 호출하여 이 컨트랙트의 balance를 0으로 만든다. 

## 1. contribute 함수를 호출하여 내 메타마스크 주소의 contribution 값을 0보다 크게 설정하기

contribute 함수를 호출하며 0.001이더보다 작은 값을 보내 내 메타마스크 주소의 contribution 값을 0보다 크게 설정해야 한다.

`contract.contribute.sendTransaction({value : toWei('0.0009')})` 로 0.0009이더를 보낸다. 

참고로 이때 toWei함수는 toWei(’ether’)의 형태로 작동하며 ether를 Wei단위로 변경하여 준다. 전송을 하거나 받을 때는 Wei단위로 이루어지기 때문으로 추측된다. 참고로 Ether의 단위는 Wei의 10^18이다.

![sendTransaction.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/aadb30e4-3f26-4756-b757-e47bd583b09d/sendTransaction.png)

그러면 메타마스크에서 트랜잭션 허용을 해달라고 뜨고 트랜잭션을 허용해준다.

![sendTransaction트랜잭션 완료.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/f9f933d2-f6af-48a4-b312-d20abc3c89ad/sendTransaction%ED%8A%B8%EB%9E%9C%EC%9E%AD%EC%85%98_%EC%99%84%EB%A3%8C.png)

그러면 트랜잭션이 완료된다. 

```solidity
  function contribute() public payable { 
    require(msg.value < 0.001 ether); // 요청한 값이 0.001이더보다 작아야함
    contributions[msg.sender] += msg.value; // 요청자에게 요청한 값만큼 이더 추가
    if(contributions[msg.sender] > contributions[owner]) { //만약 요청자가 owner보다 이더가 많으면
      owner = msg.sender; //요청자가 owner가됨
    }
  }
```

contribute 함수가 정상적으로 되었다면 contributions[player]는 정상적으로 0.0009 이더만큼 증가하였을 것이다. 이를 확인하기 위해서 getContribution함수를 확인해보자.

```jsx
  function getContribution() public view returns (uint) {
    return contributions[msg.sender]; //요청자가 소유한 이더의양 반환
  }
```

contributions[msg.sender]를 반환해 주기 때문에 실행하면 그 결과값으로 0.0009이더만큼 증가하였는지 확인할 수 있다. 단 이 때도 반환되는 값은 Wei단위이므로 fromWei를 통하여 이더의 형태로 변환해주어야 한다.

```jsx
fromWei(await contract.getContribution())
'0.0009'
```

정상적으로 들어가 있는 것을 확인할 수 있다. 

## 컨트랙트에 0.00001이더를 보내(0보다 크기만 하면 됨) recieve 함수를 호출하여 owner가 된다.

receive함수를 호출하기 위해서는 컨트랙트의 주소로 이더를 보내면 된다.

```jsx
contract.address
'0xaDd0ABA29f4B1331557Bb1B1a0aA8735d2ec5629'
```

우리는 이미 컨트랙트 주소를 알고 있으므로 이 주소로 이더를 보내자.

![이더보내기.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/0e61b5a5-2de6-4d0c-987b-03b98583df21/%EC%9D%B4%EB%8D%94%EB%B3%B4%EB%82%B4%EA%B8%B0.png)

메타마스크 지갑을 키면 보내기 버튼이 있다. 이 보내기 버튼을 누르면 보낼대상의 주소를 입력하라고 뜬다.

![보낼대상.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/b038f507-b195-4dfd-ba72-647c44df5468/%EB%B3%B4%EB%82%BC%EB%8C%80%EC%83%81.png)

이 주소에 0xaDd0ABA29f4B1331557Bb1B1a0aA8735d2ec5629를 입력하여 주면 얼마를 보낼지 입력하라고 나온다.

![이더 값 입력.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/2f057647-6e0c-46e9-a1e9-10d1b13ae680/%EC%9D%B4%EB%8D%94_%EA%B0%92_%EC%9E%85%EB%A0%A5.png)

0.0009 이더리움을 입력해주었다. 이 때 Receive함수를 호출하는 것이 목적이므로 이더를 보내는 것이 중요하지 금액의 양은 상관없다. 0이더만 아니면 된다. 

![트랜잭션허용.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/05a1c10c-954d-4880-980e-3f5dec98c41f/%ED%8A%B8%EB%9E%9C%EC%9E%AD%EC%85%98%ED%97%88%EC%9A%A9.png)

그러고 나면 전송을 위해 트랜잭션 허용이 뜬다. 트랜잭션을 허용해주어서 전송해준다.

트랜잭션이 confirmed 되고 나면 메타마스크 알림이 뜬다. 그러면 우리가 원하는 대로 Recieve 함수가 호출되어 owner 권한을 얻었는지 확인해보자.

 

```jsx
await contract.owner()
'0x83b26d6A3D3FaBd9F0A5f1d69DCA1CE6cc4eA39a'
```

contract의 owner값을 보니 내 메타마스크 주소로 변경되어 있는 것을 확인할 수 있다. owner 권한을 얻었다. 

## withdraw 함수를 호출하여 이 컨트랙트의 balance를 0으로 만든다.

```jsx
  function withdraw() public onlyOwner { // owner만 출금이가능함
    owner.transfer(address(this).balance); // owner의 주소로 이 컨트랙트의 balance만큼 이더를 보냄
  }
```

이제 owner 권한을 얻었으므로 withdraw 함수를 호출하여 이 컨트랙트에 있는 balance(자산)을 모두 내 메타마스크 주소로 빼내주면 된다.

await contract.withdraw()를 해주면 메타마스크에서 트랜잭션을 허용해 달라고 뜬다.

![트랜잭션허용2.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/3bc27c82-698a-444c-955a-eb81a74d8805/%ED%8A%B8%EB%9E%9C%EC%9E%AD%EC%85%98%ED%97%88%EC%9A%A92.png)

트랜잭션을 허용해주자.

![메타마스크 이더값.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/2d368332-7e8e-4c60-81ef-b1a4b00b337f/%EB%A9%94%ED%83%80%EB%A7%88%EC%8A%A4%ED%81%AC_%EC%9D%B4%EB%8D%94%EA%B0%92.png)

그러면 분명 receive함수를 호출하기 전에는 0.2947 이더였는데 0.2955이더로 바뀐것을 볼 수 있다. 수수료로 좀 많이 떼였지만 컨트랙트에 있는 이더를 내 메타마스크로 빼내기에 성공한 것을 알 수 있다. 

따라서 목적을 모두 달성하였으므로 ethernaut 홈페이지로 돌아가서 submit instance를 해주자.

![submit instance.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/e6d7ac05-1782-4b18-afb8-3e5b57955e1e/submit_instance.png)

트랜잭션 허용을 눌러 인스턴스를 제출해주면 

![성공.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/dc594baa-a375-4496-bb4e-055dad8207a0/%EC%84%B1%EA%B3%B5.png)

개발자 도구에서 성공했다는 창이 뜬다. 끝.
