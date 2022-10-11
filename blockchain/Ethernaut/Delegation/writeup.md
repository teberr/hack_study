https://teberr.notion.site/Ethernaut-Delegation-22b32442fda044669553767e2cd148ac

![delegation.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/1e41bcee-4cd5-4b7f-bdc0-08ab83bd796f/delegation.png)

> 
> 
> 
> 이번 문제를 해결하기 위해서는 
> 
> 1. 이 인스턴스에서 ownership 권한을 얻어내면 성공입니다
> 
> 힌트는 다음과 같습니다.
> 
> - 로우 레벨 함수에서 delegatecall 이 어떤방식으로 이루어지는지 알아보세요
> - Fallback 함수
> - 메소드 id

코드는 아래와 같다.

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

contract Delegate {

  address public owner;

  constructor(address _owner) public {
    owner = _owner;
  }

  function pwn() public {
    owner = msg.sender;
  }
}

contract Delegation {

  address public owner;
  Delegate delegate;

  constructor(address _delegateAddress) public {
    delegate = Delegate(_delegateAddress);
    owner = msg.sender;
  }

  fallback() external {
    (bool result,) = address(delegate).delegatecall(msg.data);
    if (result) {
      this;
    }
  }
```

# 코드 분석 및 공격 설계

이번 문제의 코드에서는 두 개의 컨트랙트가 존재한다.

1. Delegate 컨트랙트
2. Delegation 컨트랙트

먼저 Delegate 컨트랙트를 살펴보자

```solidity
contract Delegate {

  address public owner;

  constructor(address _owner) public {
    owner = _owner;
  }

  function pwn() public {
    owner = msg.sender;
  }
}

```

Delegate 컨트랙트는 owner가 존재하고 생성자로 이 컨트랙트가 생성될 때 전달된 주소를 owner로 설정한다.

한 편 pwn 함수를 호출하게 되면 이 함수를 호출한 msg.sender의 주소로 owner가 변경되게 된다.

그 다음 Delegation 컨트랙트를 살펴보자

```solidity
contract Delegation {

  address public owner;
  Delegate delegate;

  constructor(address _delegateAddress) public {
    delegate = Delegate(_delegateAddress);
    owner = msg.sender;
  }

  fallback() external {
    (bool result,) = address(delegate).delegatecall(msg.data);
    if (result) {
      this;
    }
  }
```

Delegate 컨트랙트를 담는 delegate와 owner가 존재한다. 이 문제에서 우리가 접근할 인스턴스는 이 Delegation의 인스턴스이며 이 인스턴스의 owner 권한을 얻어내면 된다.

그런데 이 Deleagtion의 owner는 생성자에서 인스턴스를 만든 msg.sender로 설정이 되고 delegate 컨트랙트의 인스턴스에 접근이 가능해진다.

이 코드만 보면 생성자에서만 owner를 접근할 수 있는데 우리는 생성자를 건드릴 수 없으므로 fallback 함수를 보자.

 

### Fallback 함수

fallback 함수는 이 컨트랙트의 인스턴스 주소로 이더를 보내면서 함수를 실행시킬 때 작동한다. 즉 이더를 보내며 실행이 되는 함수가 핵심이라 보면 된다.

Fall back 함수 내에서는 delegatecall을 이용해서 delegate 인스턴스의 msg.data를 실행한다. 이 때 delegatecall의 특징이 나오는데 delegatecall을 이용해서 함수를 호출하면 내 인스턴스에서 실행하는 것과 같은 효과를 얻는다. 

즉 delegatecall을 이용해서 delegate 인스턴스의 pwn()함수를 실행하기만 한다면 Delegation 인스턴스에서 실행한 것과 같은 효과가 되어 Delegation의 owner가 msg.sender로 변경이 된다. owner권한을 얻을 수 있게 되는 것이다.

### msg.data

이더를 전송할때 같이 보내는 data 값이다. 이 문제에서 delegatecall(msg.data)이므로 이 msg.data값이 delegate 컨트랙트의 pwn 함수를 의미하게 된다면 현재 인스턴스에서 pwn 함수가 실행되어 Delegation의 owner가 될 수 있다.

그렇다면 이 data는 어떤 값이 들어가야 함수를 실행할 수 있는가? 솔리디티에서 함수는 시그니쳐 기반으로 구분이된다. 그래서 함수의 시그니쳐 + 매개변수를 바이트 형태로 하여 나온 값을 call 해주더라도 그 함수를 실행하는 것과 같은 효과를 얻게 된다.

pwn()함수와 같은 사용자 정의 함수도 해쉬를 통해서 바이트로 변환하는 것이기 때문에 내가 만든 pwn()함수와 문제에서 만든 pwn()함수는 해쉬의 결과 값이 같다. 

즉 이러한 함수들의 해쉬 결과값인 시그니쳐 값들은 결과를 저장해놓은 데이터베이스들이 존재하는데 이는 [https://sig.eth.samczsun.com/](https://sig.eth.samczsun.com/) 사이트이다. 이 사이트에서 pwn()함수를 검색해보자.

![pwn 해쉬.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/f05c1146-9094-439f-8873-ec452ba2cd78/pwn_%ED%95%B4%EC%89%AC.png)

두가지의 결과값이 나온다.

1. 0xdd365b8b15d5d78ec041b851b68c8b985bee78bee0b87c4acf261024d8beabab
2. 0xdd365b8b

1번과 2번의 차이점은 1번은 해쉬함수의 결과값을 그대로 나열한 것이고 2번은 그 결과 값 중 앞 8바이트만 자른 것이다. 우리가 함수를 호출할 때는 앞의 8바이트를 기반으로 함수를 구분하므로 0xdd365b8b를 사용하면 pwn()함수를 호출하는 것이 된다.

이 방법뿐 아니라 콘솔에서도 가능하다.

```solidity
web3.eth.abi.encodeFunctionSignature("pwn()")
'0xdd365b8b'
```

똑같이 0xdd365b8b가 나오는 것을 볼 수 있다.

그러면 이제 매개변수도 바이트화 해야하는데 이 pwn()함수의 경우 매개변수가 존재하지 않으므로 추가적으로 바이트를 덧붙일 필요는 없다. 즉 0xdd365b8b 을 msg.data로 전송하면 Delegate의 pwn()함수가 실행이 된다.

# 공격

![get new instance.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/02456f73-90ce-4f4f-b03f-b63c7e1638d6/get_new_instance.png)

먼저 인스턴스에 보내야 하기 때문에 인스턴스를 새롭게 생성해준다. 참고로 이 writeup을 작성할 때는 10월 11일 자로 rinkeby 테스트넷이 종료되었기 때문에 Goreli 테스트 네트워크로 연결해서 설정해주었다.

![instance addr.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/0224a99d-2bdf-4736-92cd-b69644b43029/instance_addr.png)

인스턴스 생성 후 주소를 살펴보면 

```solidity
=> Instance address
0x7B17c76D21dEC75B71dF7cec2E5e96efcCbeD6b4
```

0x7B17c76D21dEC75B71dF7cec2E5e96efcCbeD6b4로 이더를 보내며 msg.data를 0xdd365b8b로 해서 fallback 함수를 실행시키면 된다.

sendTransaction 을 콘솔에서 사용하여 instance 주소로 0xdd365b8b를 data로 담아서 보내면 된다.

![전송.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/c05a517b-492a-4f94-abc4-199032d510e4/%EC%A0%84%EC%86%A1.png)

await contract.sendTransaction({from:player, data:’0xdd365b8b’})을 이용해서 트랜잭션을 보낸다.

![owner 권한 탈취.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/2ab5ede3-3a74-4a9f-ba60-109a09aebf09/owner_%EA%B6%8C%ED%95%9C_%ED%83%88%EC%B7%A8.png)

트랜잭션이 완료된 후 contract.owner()를 통해서 owner를 살펴보면 내 메타마스크 주소로 변경된 것을 확인할 수 있다. 문제의 목적을 달성했으므로 제출하도록하자.

![제출.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/3d3f3b82-6aab-4834-beba-7d134c5fad9a/%EC%A0%9C%EC%B6%9C.png)

submit instance를 통하여 인스턴스를 제출한다.

![성공.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/ffdbddcc-353e-4539-87b8-23f4c54fd888/%EC%84%B1%EA%B3%B5.png)

제출 후 트랜잭션이 완료 된 다음 콘솔에서 확인하면 성공한 것을 알 수 있다.
