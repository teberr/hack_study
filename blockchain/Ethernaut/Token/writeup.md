https://honey-push-30b.notion.site/Ethernaut-Token-a63d126a41ce44f190721bdb34129ab7
![문제.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/1dbdca49-3892-4483-ab29-136bf62b549a/%EB%AC%B8%EC%A0%9C.png)

> 
> 
> 
> 이번 문제를 해결하기 위해서는 이 컨트랙트의 basic 토큰을 해킹하는 것이 목표입니다.
> 
> 1. 시작 할 때 20 토큰을 가지고 시작하고 이 토큰을 추가적으로 얻어내면 성공
> 2. 토큰을 많이 얻어내는 것이 바람직 합니다.

코드는 아래와 같다.

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

contract Token {

  mapping(address => uint) balances;
  uint public totalSupply;

  constructor(uint _initialSupply) public {
    balances[msg.sender] = totalSupply = _initialSupply;
  }

  function transfer(address _to, uint _value) public returns (bool) {
    require(balances[msg.sender] - _value >= 0);
    balances[msg.sender] -= _value;
    balances[_to] += _value;
    return true;
  }

  function balanceOf(address _owner) public view returns (uint balance) {
    return balances[_owner];
  }
}
```

# 코드 분석 및 공격 설계

컨트랙트 코드를 분석해보자.

```solidity
  mapping(address => uint) balances;
  uint public totalSupply;
```

balances 변수는 주소를 key값 uint 변수가 value값으로 연결되어 저장되어 있다.

```solidity
  constructor(uint _initialSupply) public {
    balances[msg.sender] = totalSupply = _initialSupply;
  }
```

생성자로는 컨트랙트의 인스턴스가 생성될 때 이 컨트랙트의 인스턴스를 생성한 msg.sender의 주소로(level 컨트랙트의 주소일 것) initialSupply만큼 value를 설정해준다.

```solidity
  function transfer(address _to, uint _value) public returns (bool) {
    require(balances[msg.sender] - _value >= 0);
    balances[msg.sender] -= _value;
    balances[_to] += _value;
    return true;
  }
```

transfer 함수로, balance 변수에 key 값으로 msg.sender에 저장된 value에서 내가 원하는 값만큼 _to의 주소로 전송하는 함수이다. 이 때 내가 msg.sender의 잔고에서 내가 설정한 value값을 뺀 결과가0보다 커야 한다. 이 조건이 잘못되어있는 것이 uint는 범위가 0~2^256-1로 음수가 불가능한데 balances[msg.sender] - _value의 결과값도 uint -uint라서 uint 타입이라 음수가 절대 나올수가 없다.. 조건이 잘못된 것이다.

```solidity
  function balanceOf(address _owner) public view returns (uint balance) {
    return balances[_owner];
  }
```

balanceOf 함수로 balances 변수에 저장된 _owner의 value 값을 알려주는 함수이다. 이를 통해서 key값에 따라 얼마나 value가 저장되어 있는지 알 수 있다.

여기서 uint 타입을 사용한 것 뿐만 아니라 변수 선언을 할 때 safemath를 사용하지 않았다. 이 코드에서 사용한 solidity 버전은 0.6.0 버전으로 오버플로우와 언더플로우를 막아주는 safemath를 사용하지 않으면 기본적으로 오버플로우와 언더플로우에 취약하다.(0.8.0 버전부터 기본적으로 safemath를 사용하여 오버플로우와 언더플로우에 취약하지 않다.) 

따라서 오버플로우/언더플로우로 transfer함수에 접근하여 내 토큰의 개수를 20개보다 많도록 하여 목표를 달성하자.

# 공격

이제 공격 방향을 설정했으니 공격을 직접해보자.

![인스턴스 생성.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/ca178eb9-b8eb-47a1-842d-6558c3d7b47e/%EC%9D%B8%EC%8A%A4%ED%84%B4%EC%8A%A4_%EC%83%9D%EC%84%B1.png)

공격을 하기 위해서 인스턴스를 생성하고 개발자 콘솔에서 확인하자.

![인스턴스 생성1.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/6d8b3d86-2002-441c-b5f5-d32382e99ec4/%EC%9D%B8%EC%8A%A4%ED%84%B4%EC%8A%A4_%EC%83%9D%EC%84%B11.png)

레벨 컨트랙트 주소는 0x63bE8347A617476CA461649897238A31835a32CE

인스턴스 주소는 0x4Cb9EDb9215fe4AF4436ef6c86116C57558F276f

로 토큰 인스턴스가 생성된 것을 확인할 수 있다.

![레벨 컨트랙트 balance.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/ba618cf6-ac1c-4bfd-9817-5a1a34f3d46b/%EB%A0%88%EB%B2%A8_%EC%BB%A8%ED%8A%B8%EB%9E%99%ED%8A%B8_balance.png)

이 컨트랙트를 생성한 level 컨트랙트의 잔고는 20999980으로 설정되어 있음을 알 수 있다.

문제에서 내 지갑에 20 토큰이 기본적으로 있다고 하였으니 내 주소의 토큰 개수도 한번 확인해보자.

![player 주소.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/c5160017-bd3b-4160-9c7a-e1bdf2dfc1ad/player_%EC%A3%BC%EC%86%8C.png)

먼저 내 주소를 확인한 후 내 주소의 잔고를 알아보면 

 

![내 주소 토큰 개수.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/6a346f3a-ca13-4b9c-886e-c0f953fcc8a4/%EB%82%B4_%EC%A3%BC%EC%86%8C_%ED%86%A0%ED%81%B0_%EA%B0%9C%EC%88%98.png)

20개의 토큰이 있음을 알 수 있다.

오버플로우 및 언더플로우를 고려하기 위해 uint의 범위를 알아야 하는데 uint는 uint256의 약자로 uint의 범위는 0~2^256-1이다. 이제 transfer 함수를 호출해야 하는데

```solidity
  function transfer(address _to, uint _value) public returns (bool) {
    require(balances[msg.sender] - _value >= 0);
    balances[msg.sender] -= _value;
    balances[_to] += _value;
    return true;
  }
```

balance[msg.sender](20) - _value 가 uint 타입임을 생각하자. 그러면 _value가 21이 된다면 

일반적으로 생각했을 시 20-21인 -1이 결과값이 되어야하지만 uint는 아쉽게도 범위가 0~2^256-1이다. 즉 음수가 불가능하므로 언더플로우가 발생하여 -1이 아닌 2^256-1이 된다. 

이 값은 0보다 크므로 조건은 통과하게 되고 balances[msg.sender]값에서 _value를 빼게 된다.

근데 이값이 언더플로우가 발생한 2^256-1값이 되므로 balances[msg.sender]의 자산은 2^256-1이 된다. 즉 내가 이 transfer 함수를 호출하면서 아무 주소로 21을 보내게 되면 내 자산은 2^256-1이 된다.

이제 transfer 함수로 instance 주소에 토큰을 21개 보내보자.

![공격.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/7e574030-6ac4-46ff-9c0f-55a956ca7191/%EA%B3%B5%EA%B2%A9.png)

내 주소에서 인스턴스의 주소로 21개를 보냈다. 그럼 이제 언더플로우로 인하여 내 지갑의 토큰 개수는 2^256-1로 되었을 것이다. 

balanceOf함수를 통해서 내 지갑주소에 있는 토큰 개수를 확인하자

![언더플로우로 인한 토큰부자 성공.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/9ad596f5-a93b-472c-a18b-6af12ec062ef/%EC%96%B8%EB%8D%94%ED%94%8C%EB%A1%9C%EC%9A%B0%EB%A1%9C_%EC%9D%B8%ED%95%9C_%ED%86%A0%ED%81%B0%EB%B6%80%EC%9E%90_%EC%84%B1%EA%B3%B5.png)

토큰부자가 된것을 확인할 수 있다. 이제 문제 조건을 달성하였으니 인스턴스를 제출하자.

![인스턴스 제출.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/4c634ee6-6171-4347-af5e-1b1a99fadd44/%EC%9D%B8%EC%8A%A4%ED%84%B4%EC%8A%A4_%EC%A0%9C%EC%B6%9C.png)

인스턴스를 제출하고 개발자 도구 콘솔에서 트랜잭션이 완료되기를 기다리면..

![성공.PNG](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/720ff586-5bf9-4cdb-a953-af0084bb82fe/%EC%84%B1%EA%B3%B5.png)

이 문제를 해결했음을 알리는 표시가 나온다. 성공!
